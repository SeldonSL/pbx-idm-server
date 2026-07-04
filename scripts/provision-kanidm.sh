#!/usr/bin/env bash
set -euo pipefail
# Dia-1, paso 2/3: dejar Kanidm funcionando.
# Ejecutar como root en el servidor, DESPUES de provision-tailscale.sh.

source /etc/pbx-idm/env
if [ "${TS_FQDN:-PENDIENTE}" = "PENDIENTE" ]; then
    echo "ERROR: TS_FQDN sin configurar. Corre antes scripts/provision-tailscale.sh"
    exit 1
fi

TEMPLATES="$(cd "$(dirname "$0")/templates" && pwd)"

echo "== 1/5 Directorio de datos =="
install -d -m 0750 /var/lib/kanidm/data

echo "== 2/5 server.toml (domain=${TS_FQDN} — decision permanente, ver docs/decisions.md) =="
sed "s|@FQDN@|${TS_FQDN}|g" "$TEMPLATES/server.toml.tmpl" > /var/lib/kanidm/data/server.toml
chmod 0640 /var/lib/kanidm/data/server.toml

echo "== 3/5 Certificado TLS via Tailscale =="
systemctl start tailscale-cert.service

echo "== 4/5 Validando configuracion (configtest) =="
podman run --rm -i -v /var/lib/kanidm/data:/data:Z \
    docker.io/kanidm/server:1.10.4 kanidmd configtest

echo "== 5/5 Arrancando kanidm.service =="
systemctl daemon-reload
systemctl start kanidm.service
sleep 5
systemctl --no-pager --lines=5 status kanidm.service

echo
echo "== Credenciales de administracion: GUARDALAS EN TU GESTOR DE CONTRASEÑAS =="
echo "-- cuenta admin (administra el servidor kanidm):"
podman exec -it kanidm kanidmd recover-account admin
echo "-- cuenta idm_admin (administra usuarios y grupos):"
podman exec -it kanidm kanidmd recover-account idm_admin

echo
echo "Kanidm listo: https://${TS_FQDN}:8443"
echo "Siguiente: scripts/provision-freepbx.sh"
