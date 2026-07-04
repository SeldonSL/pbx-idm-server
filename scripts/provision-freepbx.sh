#!/usr/bin/env bash
set -euo pipefail
# Dia-1, paso 3/3: crear el contenedor de sistema Debian 12 e instalar FreePBX 17.
# Ejecutar como root en el servidor. Duracion total: 45-90 minutos.
# Vigilar en otra terminal:  journalctl -u systemd-nspawn@freepbx -f
# Si hay problemas SELinux:  ausearch -m avc -ts recent

MACHINE=/var/lib/machines/freepbx
TEMPLATES="$(cd "$(dirname "$0")/templates" && pwd)"

if [ -e "$MACHINE" ]; then
    echo "ERROR: $MACHINE ya existe. Si quieres rehacer desde cero:"
    echo "  machinectl stop freepbx; machinectl disable freepbx; rm -rf $MACHINE"
    exit 1
fi

echo "== 1/8 Descargando rootfs Debian 12 (images.linuxcontainers.org) =="
INDEX_URL=https://images.linuxcontainers.org/images/debian/bookworm/amd64/default
BUILD=$(curl -fsSL "$INDEX_URL/" | grep -oP '\d{8}_\d{2}%3A\d{2}|\d{8}_\d{2}:\d{2}' | sed 's/%3A/:/' | sort | tail -1)
echo "   build: $BUILD"
curl -fLo /var/tmp/freepbx-rootfs.tar.xz "$INDEX_URL/$BUILD/rootfs.tar.xz"
mkdir -p "$MACHINE"
tar -xJf /var/tmp/freepbx-rootfs.tar.xz -C "$MACHINE"
rm -f /var/tmp/freepbx-rootfs.tar.xz

echo "== 2/8 Etiquetado SELinux (antes del primer arranque) =="
semanage fcontext -a -t container_file_t "/var/lib/machines(/.*)?" 2>/dev/null || true
restorecon -R /var/lib/machines

echo "== 3/8 Preparacion offline del rootfs =="
# --register=no: este es un comando efimero de preparacion, no la maquina real;
# ademas el registro en machined falla si el script corre como servicio.
systemd-nspawn --register=no -D "$MACHINE" --pipe /bin/bash <<'EOF'
set -e
# El instalador de Sangoma exige un FQDN (nombre con puntos) en hostname y hosts
echo freepbx.internal > /etc/hostname
echo "127.0.1.1 freepbx.internal freepbx" >> /etc/hosts
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y dbus curl wget gnupg2 sudo locales unattended-upgrades
EOF

echo "== 4/8 Arrancando la maquina =="
mkdir -p /var/backups/pbx-idm/freepbx
machinectl enable freepbx
machinectl start freepbx
# Esperar a que el systemd interno este listo (un sleep fijo genera carreras)
echo "   esperando a que la maquina responda..."
for i in $(seq 1 60); do
    systemd-run --machine=freepbx --pipe --wait /bin/true >/dev/null 2>&1 && break
    [ "$i" -eq 60 ] && { echo "ERROR: la maquina freepbx no respondio en 120s"; exit 1; }
    sleep 2
done
machinectl list

echo "== 5/8 Instalador oficial FreePBX 17 (30-60 min — NO interrumpir) =="
# El instalador deja los demonios (asterisk, fwconsole) corriendo en su propia
# sesion: hay que detenerlos para que systemd-run pueda retornar. Arrancan
# limpios via freepbx.service tras el reinicio del paso 7.
systemd-run --machine=freepbx --pipe --wait /bin/bash -c \
    'curl -fLo /tmp/inst.sh https://github.com/FreePBX/sng_freepbx_debian_install/raw/master/sng_freepbx_debian_install.sh && bash /tmp/inst.sh; rc=$?; fwconsole stop --immediate >/dev/null 2>&1 || true; exit $rc'

echo "== 6/8 Tuning MariaDB y updates internos (solo archivos) =="
cp "$TEMPLATES/99-pbx-idm-mariadb.cnf" "$MACHINE/etc/mysql/mariadb.conf.d/99-pbx-idm.cnf"
cp "$TEMPLATES/52-pbx-idm-unattended.conf" "$MACHINE/etc/apt/apt.conf.d/"
cp "$TEMPLATES/freepbx-module-upgrade.service" "$MACHINE/etc/systemd/system/"
cp "$TEMPLATES/freepbx-module-upgrade.timer" "$MACHINE/etc/systemd/system/"

echo "== 7/8 Reinicio limpio de la maquina =="
machinectl reboot freepbx
for i in $(seq 1 60); do
    systemd-run --machine=freepbx --pipe --wait /bin/true >/dev/null 2>&1 && break
    [ "$i" -eq 60 ] && { echo "ERROR: la maquina no volvio tras el reboot"; exit 1; }
    sleep 3
done
systemd-run --machine=freepbx --pipe --wait systemctl enable --now freepbx-module-upgrade.timer

echo "== 8/8 Verificacion y HTTPS =="
systemd-run --machine=freepbx --pipe --wait /bin/bash -c \
    'sleep 15; systemctl is-active freepbx mariadb apache2 freepbx-module-upgrade.timer'
# GUI con HTTPS real (cert automatico de Tailscale, candado en el navegador).
# El trafico http:80 ya viajaba cifrado por el tunel, pero asi el navegador lo sabe.
tailscale serve --bg --https=443 http://127.0.0.1:80
cat <<'FIN'

PASOS MANUALES EN LA GUI (http://<fqdn-tailscale> desde un equipo en la tailnet):
 1. Primer acceso: definir password de admin -> guardarlo en el gestor de contraseñas.
 2. Settings -> Asterisk SIP Settings:
      Local Networks: 100.64.0.0/10 + LAN sede A + LAN sede B
      RTP Port Ranges: 10000-20000
 3. Modulo Backup: job nocturno 01:30 -> storage Local -> directorio /var/backups/host
 4. Crear extensiones y probar llamada entre dos softphones.

NOTA fase 4 del plan: verificar el origen real del repo Sangoma para unattended-upgrades:
  systemd-run --machine=freepbx --pipe --wait apt-cache policy
y ajustar 52-pbx-idm-unattended.conf si el patron "site=deb.freepbx.org" no coincide.
FIN
