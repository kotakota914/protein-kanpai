# 台本（script.json）の speech を、Kokoro（Apache 2.0 の音声合成モデル）で読み上げる
import json, sys, pathlib
import numpy as np, soundfile as sf
from kokoro import KPipeline

here = pathlib.Path(__file__).parent
out = here / 'audio'; out.mkdir(exist_ok=True)
voice = sys.argv[1] if len(sys.argv) > 1 else 'jf_alpha'
pipe = KPipeline(lang_code='j')
durations = {}
for seg in json.load(open(here / 'script.json', encoding='utf-8')):
    chunks = [a for _, _, a in pipe(seg['speech'], voice=voice, speed=1.0)]
    audio = np.concatenate([np.asarray(c) for c in chunks])
    sf.write(out / f"{seg['id']}.wav", audio, 24000)
    durations[seg['id']] = round(len(audio) / 24000, 2)
    print(seg['id'], durations[seg['id']], flush=True)
json.dump(durations, open(here / 'durations.json', 'w'), indent=2)
