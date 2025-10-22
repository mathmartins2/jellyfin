#!/usr/bin/env bash
set -euo pipefail

# Esperado via ENV:
# RCLONE_CONFIG_GDRIVE_TYPE=drive
# RCLONE_CONFIG_GDRIVE_SCOPE=drive.readonly  (ou drive)
# RCLONE_CONFIG_GDRIVE_TOKEN={JSON do rclone authorize}
# (Opcional) RCLONE_CONFIG_GDRIVE_TEAM_DRIVE=ID_DO_SHARED_DRIVE
# MEDIA_FOLDER_ID=ID_DA_PASTA_NO_DRIVE (ex.: 1-HX0p5jsfRpvf3kQSNaFLawRzUABly_T)
# MEDIA_PATH=/data/media
# SYNC_MODE=copy|sync   (default: copy)
# SYNC_ON_BOOT=true|false (default: true)
# SYNC_INTERVAL_MIN=0   (0 = sem loop; >0 = sync periódico em minutos)

: "${MEDIA_PATH:=/data/media}"
: "${SYNC_MODE:=copy}"
: "${SYNC_ON_BOOT:=true}"
: "${SYNC_INTERVAL_MIN:=0}"

mkdir -p "$MEDIA_PATH"

log() { printf '%s %s\n' "[$(date +'%Y-%m-%d %H:%M:%S')]" "$*"; }

do_sync() {
  if [[ -n "${MEDIA_FOLDER_ID:-}" ]]; then
    log "[rclone] ${SYNC_MODE} do Google Drive (folderId=${MEDIA_FOLDER_ID}) → ${MEDIA_PATH}"
    # Usa somente variáveis de ENV; ok não ter rclone.conf
    rclone "${SYNC_MODE}" "gdrive:" "${MEDIA_PATH}" \
      --drive-root-folder-id "${MEDIA_FOLDER_ID}" \
      --fast-list --transfers=4 --checkers=8 --progress --update || \
      log "[rclone] aviso: falha no sync (seguindo sem parar o Jellyfin)"
  else
    log "[rclone] MEDIA_FOLDER_ID não definido; pulando sync."
  fi
}

# Sync inicial
if [[ "${SYNC_ON_BOOT}" == "true" ]]; then
  do_sync || true
fi

# Sync periódico
if [[ "${SYNC_INTERVAL_MIN}" -gt 0 ]]; then
  (
    while true; do
      sleep "$(( SYNC_INTERVAL_MIN * 60 ))"
      do_sync || true
    done
  ) &
fi

# Descobre o binário do Jellyfin na imagem
JELLYFIN_BIN="$(command -v jellyfin || true)"
if [[ -z "${JELLYFIN_BIN}" ]]; then
  for p in /usr/lib/jellyfin/bin/jellyfin /jellyfin/jellyfin /usr/bin/jellyfin; do
    [[ -x "$p" ]] && JELLYFIN_BIN="$p" && break
  done
fi

if [[ -z "${JELLYFIN_BIN}" ]]; then
  log "[erro] Jellyfin não encontrado no container."
  log "Dica: você está realmente usando a imagem 'jellyfin/jellyfin:latest'?"
  exit 1
fi

log "[jellyfin] iniciando: ${JELLYFIN_BIN} $*"
exec "${JELLYFIN_BIN}" "$@"
