#!/usr/bin/env bash
set -euxo pipefail

# Paquetes sobre ucore-minimal:
#  - systemd-container: machinectl + systemd-nspawn (contenedor de sistema FreePBX)
#  - jq: usado por los scripts de operación
if command -v dnf5 >/dev/null 2>&1; then
    dnf5 install -y systemd-container jq
else
    rpm-ostree install systemd-container jq
fi

# Hora local del servidor: los OnCalendar de todos los timers son hora local
ln -sf /usr/share/zoneinfo/America/Santiago /etc/localtime

# Updates del SO: uCore trae rpm-ostreed en modo "stage" (descarga sin reiniciar).
# Lo sustituimos por bootc, que aplica Y reinicia — solo si hay imagen nueva —
# a las 04:00 (ver drop-in 10-schedule.conf del timer).
systemctl disable rpm-ostreed-automatic.timer
systemctl enable bootc-fetch-apply-updates.timer

# Contenedores
systemctl enable podman-auto-update.timer
systemctl enable machines.target

# Servicios base
systemctl enable tailscaled.service
systemctl enable cockpit.socket
systemctl enable tailscale-cert.timer
systemctl enable pbx-idm-backup.timer

# Limpieza de caches del build
if command -v dnf5 >/dev/null 2>&1; then dnf5 clean all; fi
rm -rf /var/cache/* /var/lib/dnf 2>/dev/null || true
