FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install \
    --no-cache-dir \
    --root-user-action=ignore \
    -r requirements.txt

COPY . .

# Commit SHA passed in by the CI pipeline (--build-arg APP_VERSION=<sha>).
# Exposed through /health so each slot shows exactly which build it runs.
ARG APP_VERSION=local
ENV APP_VERSION=${APP_VERSION}

RUN useradd -m appuser \
    && chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]