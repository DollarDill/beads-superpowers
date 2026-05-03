FROM debian:12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl python3 tar ca-certificates && \
    rm -rf /var/lib/apt/lists/*
RUN useradd -m testuser
USER testuser
WORKDIR /home/testuser
