# Cloud Run 用。`gcloud run deploy --source backend` が Cloud Build でこのファイルからビルドする（手元に docker は不要）。
FROM python:3.13-slim

# uv は公式イメージからバイナリだけ取る（pip でのインストールより速く、版を固定できる）
COPY --from=ghcr.io/astral-sh/uv:0.12.13 /uv /uvx /bin/

WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PYTHONUNBUFFERED=1 \
    PORT=8080

# 依存だけ先に入れて、コード変更のたびに再解決しないようにする
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY app ./app

ENV PATH="/app/.venv/bin:$PATH"
EXPOSE 8080
# --forwarded-allow-ips="*" は、Cloud Run のプロキシが付ける X-Forwarded-Proto を信じて URL を https で組み立てるため
# （コンテナに届くのはそのプロキシからだけ）
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --proxy-headers --forwarded-allow-ips='*'"]
