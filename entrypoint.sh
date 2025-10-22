#!/usr/bin/env bash
set -euo pipefail

# ==============================
# VARIÁVEIS ESPERADAS
# ==============================
# RCLONE_CONFIG_GDRIVE_TYPE=drive
# RCLONE_CONFIG_GDRIVE_SCOPE=drive.readonly
# RCLONE_CONFIG_GDRIVE_TOKEN={JSON do rclone authorize}
# (Opcional) RCLONE_CONFIG_GDRIVE_TEAM_DRIVE=ID_DO_SHARED_DRIVE
# MEDIA_FOLDER_ID=ID_DA_PASTA_NO_DRIVE
# MEDIA_PATH=/data/media
# SYNC_MODE=copy|sync
# SYNC_ON_BOOT=true|false
# SYNC_INTERVAL_MIN=0
# FORCE_COPY=true|false
# ==============================

: "${MEDIA_PATH:=/data/media}"
: "${SYNC_MODE:=copy}"
: "${SYNC_ON_BOOT:=true}"
: "${SYNC_INTERVAL_MIN:=0}"
: "${FORCE_COPY:=false}"

# Cria diretórios persistentes
mkdir -p /data/{data,config,cache,media}

# =================================
# FUNÇÃO DE SINCRONIZAÇÃO DO GDRIVE
# =================================
do_sync() {
  if [[ -n "${MEDIA_FOLDER_ID:-}" ]]; then
    echo "[rclone] ${SYNC_MODE^^} do Google Drive (folderId=${MEDIA_FOLDER_ID}) → ${MEDIA_PATH}"

    EXTRA_FLAGS=""
    if [[ "${FORCE_COPY}" == "true" ]]; then
      EXTRA_FLAGS="--ignore-times --checksum"
    else
      EXTRA_FLAGS="--ignore-existing"
    fi

    rclone "${SYNC_MODE}" "gdrive:" "${MEDIA_PATH}" \
      --drive-root-folder-id "${MEDIA_FOLDER_ID}" \
      --fast-list --transfers=4 --checkers=8 --progress --update ${EXTRA_FLAGS} || \
      echo "[rclone] aviso: falha no sync, seguindo..."
  else
    echo "[rclone] MEDIA_FOLDER_ID não definido; pulando sync."
  fi
}

# =================================
# EXECUTA SYNC NO BOOT
# =================================
if [[ "${SYNC_ON_BOOT}" == "true" ]]; then
  do_sync || true
fi

# =================================
# LOOP PERIÓDICO (OPCIONAL)
# =================================
if [[ "${SYNC_INTERVAL_MIN}" -gt 0 ]]; then
  (
    while true; do
      sleep "$(( SYNC_INTERVAL_MIN * 60 ))"
      do_sync || true
    done
  ) &
fi

# =================================
# INICIA O JELLYFIN
# =================================
JELLYFIN_BIN="$(command -v jellyfin || true)"
if [[ -z "$JELLYFIN_BIN" ]]; then
  for p in /usr/lib/jellyfin/bin/jellyfin /jellyfin/jellyfin /usr/bin/jellyfin; do
    [[ -x "$p" ]] && JELLYFIN_BIN="$p" && break
  done
fi

if [[ -z "$JELLYFIN_BIN" ]]; then
  echo "[ERRO] Jellyfin não encontrado na imagem."
  exit 1
fi

echo "[jellyfin] iniciando com config persistente..."
exec "$JELLYFIN_BIN" \
  --datadir /data/data \
  --configdir /data/config \
  --cachedir /data/cache \
  "$@"
