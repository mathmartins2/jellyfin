#!/usr/bin/env bash
set -euo pipefail

# Variáveis esperadas:
# RCLONE_CONFIG_GDRIVE_TYPE=drive
# RCLONE_CONFIG_GDRIVE_SCOPE=drive.readonly  (ou drive)
# RCLONE_CONFIG_GDRIVE_TOKEN={JSON do rclone authorize}
# Opcional: RCLONE_CONFIG_GDRIVE_TEAM_DRIVE=ID_DO_SHARED_DRIVE
# MEDIA_FOLDER_ID=ID_DA_PASTA_NO_DRIVE (ex.: 1-HX0p5jsfRpvf3kQSNaFLawRzUABly_T)
# MEDIA_PATH=/data/media
# SYNC_MODE=copy|sync  (default: copy)
# SYNC_ON_BOOT=true|false (default: true)
# SYNC_INTERVAL_MIN=0  (0 = não repetir; >0 = sync periódico em minutos)

: "${MEDIA_PATH:=/data/media}"
: "${SYNC_MODE:=copy}"
: "${SYNC_ON_BOOT:=true}"
: "${SYNC_INTERVAL_MIN:=0}"

mkdir -p "$MEDIA_PATH"

do_sync() {
  if [[ -n "${MEDIA_FOLDER_ID:-}" ]]; then
    echo "[rclone] ${SYNC_MODE} do Google Drive (folderId=${MEDIA_FOLDER_ID}) → ${MEDIA_PATH}"
    rclone "${SYNC_MODE}" "gdrive:" "${MEDIA_PATH}" \
      --drive-root-folder-id "${MEDIA_FOLDER_ID}" \
      --fast-list --transfers=4 --checkers=8 --progress --update
  else
    echo "[rclone] MEDIA_FOLDER_ID não definido; pulando sync."
  fi
}

# Sync inicial (opcional)
if [[ "${SYNC_ON_BOOT}" == "true" ]]; then
  do_sync || true
fi

# Sync periódico (opcional)
if [[ "${SYNC_INTERVAL_MIN}" -gt 0 ]]; then
  (
    while true; do
      sleep "$(( SYNC_INTERVAL_MIN * 60 ))"
      do_sync || true
    done
  ) &
fi

echo "[jellyfin] iniciando servidor..."
exec /usr/lib/jellyfin/bin/jellyfin
