/// キャラクター（シェイカーくん）の成長段階。
///
/// プロテインを飲んだ量ではなく、**振った日数（＝筋トレした日数）**で育つ。
/// 1 日に何回振っても 1 日分しか数えないので、飲みすぎを促さない。
class GrowthStage {
  const GrowthStage(this.level, this.name, this.minDays);

  final int level;
  final String name;

  /// この段階になるのに必要な、振った日数の合計
  final int minDays;
}

const growthStages = [
  GrowthStage(1, 'ひよっこ', 0),
  GrowthStage(2, 'ちょいマッチョ', 3),
  GrowthStage(3, '細マッチョ', 7),
  GrowthStage(4, 'マッチョ', 14),
  GrowthStage(5, 'ムキムキ', 30),
];

/// 振った日数の合計から、いまの段階を返す
GrowthStage stageFor(int totalDays) {
  var current = growthStages.first;
  for (final s in growthStages) {
    if (totalDays >= s.minDays) current = s;
  }
  return current;
}

/// 次の段階（いちばん上なら null）
GrowthStage? nextStageAfter(GrowthStage stage) {
  final i = growthStages.indexOf(stage);
  return i + 1 < growthStages.length ? growthStages[i + 1] : null;
}
