FROM jellyfin/jellyfin:latest

RUN apt-get update && \
    apt-get install -y --no-install-recommends rclone ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV MEDIA_PATH="/data/media"

ENTRYPOINT ["/entrypoint.sh"]
