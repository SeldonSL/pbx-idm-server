#!/usr/bin/env bash
set -euo pipefail
# Dia-1, paso 1/3: conectar el servidor a la tailnet.
# Ejecutar como root EN EL SERVIDOR (desde consola fisica, o SSH inicial por LAN
# si el firewall aun no esta asignado a la NIC).

echo "== Conectando a Tailscale (se abrira una URL de login para autorizar) =="
tailscale up --ssh --accept-routes

FQDN=$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\.$//')
if [ -z "$FQDN" ] || [ "$FQDN" = "null" ]; then
    echo "ERROR: no se pudo obtener el FQDN. ¿MagicDNS esta activado en la consola de Tailscale?"
    exit 1
fi

sed -i "s|^TS_FQDN=.*|TS_FQDN=${FQDN}|" /etc/pbx-idm/env
echo
echo "OK: este servidor es ${FQDN}"
echo
echo "PASOS MANUALES AHORA (consola web https://login.tailscale.com/admin):"
echo "  1. Machines -> pbx-idm -> Disable key expiry (que el nodo nunca caduque)"
echo "  2. DNS -> verificar MagicDNS ON y HTTPS Certificates ON"
echo
echo "Siguiente: scripts/provision-kanidm.sh"
