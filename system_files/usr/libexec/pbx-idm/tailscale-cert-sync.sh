#!/usr/bin/env bash
set -euo pipefail

# TS_FQDN viene de /etc/pbx-idm/env (EnvironmentFile del service)
: "${TS_FQDN:?falta TS_FQDN en /etc/pbx-idm/env}"

DEST=/var/lib/kanidm/data/tls
install -d -m 0755 "$DEST"

before=$(sha256sum "$DEST/fullchain.pem" 2>/dev/null | cut -d' ' -f1 || true)

# tailscale solo re-emite si el certificado esta cerca de expirar (Let's Encrypt, 90 dias)
tailscale cert \
    --cert-file "$DEST/fullchain.pem" \
    --key-file "$DEST/key.pem" \
    "$TS_FQDN"

chmod 0644 "$DEST/fullchain.pem"
chmod 0640 "$DEST/key.pem"

after=$(sha256sum "$DEST/fullchain.pem" | cut -d' ' -f1)

# Reiniciar kanidm solo si el certificado realmente cambio
if [ "$before" != "$after" ] && systemctl is-active --quiet kanidm.service; then
    systemctl restart kanidm.service
fi
