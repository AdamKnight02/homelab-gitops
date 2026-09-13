# state-api image — distroless-style, non-root, minimal attack surface.
FROM python:3.12-slim AS builder

WORKDIR /build
COPY src/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/app/bin:${PATH}" \
    PYTHONPATH="/app"

RUN groupadd -r stateapi -g 10001 && useradd -r -g stateapi -u 10001 stateapi

COPY --from=builder /install /usr/local
COPY src/app /app/app

USER 10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request;urllib.request.urlopen('http://127.0.0.1:8080/healthz',timeout=3)" || exit 1

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "2"]
