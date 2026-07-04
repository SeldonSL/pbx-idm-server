# Instalación del servidor (VM de prueba o mini PC real)

Guía corta y mecánica. La explicación completa está en `docs/setup-guide.md`.

## 1. Generar el hash de la contraseña de rescate

Esta contraseña solo sirve para entrar con teclado y monitor si Tailscale falla.
Elige una frase larga, guárdala en tu gestor de contraseñas, y genera su hash:

```bash
openssl passwd -6
# (pide la contraseña dos veces y escupe una linea que empieza con $6$...)
```

Copia esa línea en `installer/pbx-idm.butane` reemplazando `REEMPLAZAR_HASH`.
**No commitees ese cambio** (`git restore installer/pbx-idm.butane` después de compilar).

## 2. Compilar el ignition

```bash
podman run -i --rm quay.io/coreos/butane:release --pretty --strict \
  < installer/pbx-idm.butane > pbx-idm.ign
```

El `.ign` queda fuera de git (está en `.gitignore`).

## 3a. Instalar en VM de prueba (hacer SIEMPRE primero)

```bash
# Descargar disco base de Fedora CoreOS (una vez)
podman run --pull=always --rm -v .:/data -w /data \
  quay.io/coreos/coreos-installer:release download -s stable -p qemu -f qcow2.xz --decompress

# Crear la VM (4GB RAM como el equipo real)
virt-install --name pbx-idm-test --memory 4096 --vcpus 2 \
  --os-variant fedora-coreos-stable --import \
  --disk size=40,backing_store=$PWD/fedora-coreos-*-qemu.x86_64.qcow2 \
  --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=$PWD/pbx-idm.ign"
```

La VM se reinicia sola 2 veces (etapas de conversión). Al terminar: login como
`core` y verificar con `sudo bootc status` que corre `pbx-idm-server:stable`.

## 3b. Instalar en el mini PC real

1. Grabar la ISO live de Fedora CoreOS en un USB
   (descarga: https://fedoraproject.org/coreos/download?stream=stable).
2. Copiar `pbx-idm.ign` a otro USB (o servirlo por HTTP en tu red).
3. Arrancar el mini PC desde el USB y ejecutar:

```bash
sudo coreos-installer install /dev/sda --ignition-file /ruta/al/pbx-idm.ign
# (verificar el disco destino con lsblk antes: puede ser /dev/nvme0n1)
sudo reboot
```

4. Esperar los 2 reinicios de conversión. Luego seguir con
   `scripts/provision-tailscale.sh` (ver docs/setup-guide.md, paso "Día 1").
