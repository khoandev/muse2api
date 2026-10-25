# syntax=docker/dockerfile:1

# --- build stage: install the package into a self-contained virtualenv --------
FROM python:3.12-slim-bookworm AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app
COPY pyproject.toml README.md ./
COPY src ./src

# Drop pip and bytecode caches from the venv: the runtime never installs anything.
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --no-cache-dir . \
 && rm -rf /opt/venv/bin/pip* /opt/venv/lib/python3.12/site-packages/pip* \
 && find /opt/venv -type d -name __pycache__ -prune -exec rm -rf {} +

# --- runtime stage: venv + headless Chromium, nothing else --------------------
FROM python:3.12-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:$PATH" \
    MUSE2API_HOST=0.0.0.0 \
    MUSE2API_DATA_DIR=/app/data \
    MUSE2API_CHROMIUM_PATH=/usr/bin/chromium

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates \
        chromium \
        fonts-wqy-zenhei \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /usr/share/doc/* /usr/share/man/* \
 && find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} + \
 && rm -rf /usr/local/lib/python3.12/site-packages/pip*

COPY --from=builder /opt/venv /opt/venv

RUN useradd --create-home --uid 1000 muse \
 && mkdir -p /app/data \
 && chown -R muse:muse /app

WORKDIR /app
USER muse

EXPOSE 18610
CMD ["muse2api"]
