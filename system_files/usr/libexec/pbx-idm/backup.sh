#!/usr/bin/env bash
set -euo pipefail

ROOT=/var/backups/pbx-idm
DATE=$(date +%F)
install -d "$ROOT/freepbx" "$ROOT/kanidm" "$ROOT/etc"

# 1) FreePBX: el job del modulo Backup (01:30, dentro del nspawn) deja su .tar.gz
#    directamente en $ROOT/freepbx via el Bind= de freepbx.nspawn. Nada que hacer.

# 2) Kanidm: online_backup (22:00, config en server.toml) escribe en /data/backups
latest=$(ls -1t /var/lib/kanidm/data/backups/ 2>/dev/null | head -1 || true)
if [ -n "$latest" ]; then
    cp -a "/var/lib/kanidm/data/backups/$latest" "$ROOT/kanidm/"
fi

# 3) Configuracion no cubierta por la imagen: /etc del nspawn y /etc/pbx-idm del host
if [ -d /var/lib/machines/freepbx/etc ]; then
    tar czf "$ROOT/etc/freepbx-etc-$DATE.tar.gz" -C /var/lib/machines/freepbx etc
fi
if [ -d /etc/pbx-idm ]; then
    tar czf "$ROOT/etc/host-etc-$DATE.tar.gz" -C / etc/pbx-idm
fi

# 4) Rotacion: 14 dias
find "$ROOT" -type f -mtime +14 -delete

# 5) FUTURO destino remoto (restic) — activar cuando exista destino:
#    export RESTIC_REPOSITORY=...   RESTIC_PASSWORD_FILE=/etc/pbx-idm/restic.pass
#    restic backup "$ROOT" && restic forget --keep-daily 14 --keep-weekly 8 --prune
