# Guía de instalación paso a paso (en lenguaje llano)

Escrita para alguien que sabe programar pero no administra servidores.
Cada paso dice **en qué máquina** se ejecuta y **qué deberías ver**.

## La idea general

- Este repo es la "receta" del servidor, como un `Dockerfile` + `requirements.txt`
  pero para el sistema operativo completo.
- GitHub Actions construye la imagen cada noche y la firma digitalmente.
- El servidor revisa a las 04:00 si hay imagen nueva; si la hay, la aplica y se
  reinicia solo. Tus datos (llamadas, usuarios, bases de datos) viven aparte en
  `/var` y nunca se tocan.
- Si un update rompe algo: `sudo bootc rollback && sudo reboot` = volver a ayer.

## Los 5 secretos (qué son y dónde viven)

| # | Secreto | Para qué | Cómo se crea (una vez) | Dónde queda |
|---|---|---|---|---|
| 1 | Clave de firma cosign | El servidor verifica que la imagen la construiste tú | `cosign generate-key-pair` en tu desktop | Privada: GitHub Secrets (`SIGNING_SECRET`) + gestor de contraseñas. Pública: en el repo |
| 2 | Auth de Tailscale | Unir el servidor a tu red privada | `tailscale up` en el servidor abre una URL; la autorizas desde tu navegador | En ningún lado: es un login de una sola vez |
| 3 | Contraseña de consola física | Rescate con teclado y monitor si Tailscale falla | `openssl passwd -6` en tu desktop; el hash va al butane ANTES de compilar (no se commitea) | La contraseña real: gestor de contraseñas |
| 4 | Contraseñas de Kanidm (`admin`, `idm_admin`) | Administrar identidad | Las **genera Kanidm** durante `provision-kanidm.sh` y las muestra en pantalla | Gestor de contraseñas |
| 5 | Contraseña admin de FreePBX | GUI de la central telefónica | La defines en el navegador en el primer acceso | Gestor de contraseñas |

Regla: configuración → git. Credenciales → JAMÁS en git.

## Fase A — Preparación (tu desktop, una vez) — YA HECHA si lees esto en el repo

1. Repo creado, claves cosign generadas, `SIGNING_SECRET` subido.
2. **Pendiente manual tuyo**: en https://login.tailscale.com/admin/dns activar
   **MagicDNS** y **HTTPS Certificates** (dos toggles). Sin esto, Kanidm no
   tendrá certificado.
3. **Pendiente manual tuyo (tras el primer build)**: en GitHub →
   `Packages` → `pbx-idm-server` → Package settings → Change visibility →
   **Public**. GitHub crea los paquetes como privados aunque el repo sea público,
   y el servidor necesita descargarlo sin credenciales.
4. Respalda `cosign.key` en tu gestor de contraseñas (copia el contenido del
   archivo) y luego bórralo del desktop si quieres máxima prolijidad.

## Fase B — Instalar el servidor

Sigue `installer/README.md` (VM de prueba primero, SIEMPRE). Resumen:
compilar `pbx-idm.ign` → arrancar el instalador de Fedora CoreOS → el sistema
se convierte solo en `pbx-idm-server:stable` con 2 reinicios (~10 min).

**Qué deberías ver al final**: login `core@pbx-idm`, y `sudo bootc status`
mostrando `ghcr.io/seldonsl/pbx-idm-server:stable`.

## Fase C — Día 1: los tres scripts de provisión (en el servidor, en orden)

Copia la carpeta `scripts/` al servidor (`scp -r scripts/ core@<ip>:` o clona el
repo) y ejecuta como root:

1. `sudo ./scripts/provision-tailscale.sh`
   — te dará una URL para autorizar el servidor en tu cuenta Tailscale.
   Después: en la consola web, desactiva la expiración de la clave del nodo.
2. `sudo ./scripts/provision-kanidm.sh`
   — al final imprime las contraseñas de `admin` e `idm_admin`: **cópialas al
   gestor de contraseñas en ese momento**, no se pueden volver a ver (solo
   regenerar).
3. `sudo ./scripts/provision-freepbx.sh`
   — demora 45-90 min. Al final lista los pasos manuales de la GUI (contraseña
   admin, redes locales, job de backup).

## Fase D — Cerrar el candado (en el servidor)

```bash
# Averigua el nombre de tu conexión de red y asígnala a la zona restrictiva:
nmcli con show
sudo nmcli con mod "<nombre>" connection.zone lan
sudo firewall-cmd --reload
```

Desde ese momento: administración solo vía Tailscale. Si algo sale mal, la
consola física (secreto #3) siempre funciona.

## URLs finales (desde cualquier equipo tuyo con Tailscale)

- FreePBX: `https://pbx-idm.<tu-tailnet>.ts.net` (GUI con candado vía tailscale serve)
- Kanidm: `https://pbx-idm.<tu-tailnet>.ts.net:8443`
- Cockpit (monitoreo): `https://pbx-idm.<tu-tailnet>.ts.net:9090`
