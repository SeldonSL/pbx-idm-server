# pbx-idm-server

Servidor inmutable para telefonía (FreePBX 17) e identidad (Kanidm), accesible
solo por Tailscale, pensado para un mini PC x86_64 con 4 GB de RAM.

**Cómo funciona en una frase:** este repo es la "receta" del sistema operativo;
GitHub Actions construye cada noche una imagen (`ghcr.io/seldonsl/pbx-idm-server:stable`)
firmada con cosign, y el servidor la descarga y se reinicia solo a las 04:00
únicamente si hay versión nueva. Rollback en un comando si algo sale mal.

| Componente | Cómo corre | Actualización |
|---|---|---|
| SO (uCore/Fedora CoreOS) | imagen inmutable bootc | diaria 04:00, automática, con rollback |
| Kanidm | contenedor podman (quadlet) | tag fijado; bump deliberado vía git |
| FreePBX 17 | contenedor de sistema nspawn (Debian 12) | unattended-upgrades + fwconsole semanal |

## Mapa del repo

- `Containerfile` + `build_files/` — la receta de la imagen del SO
- `system_files/` — archivos que van dentro de la imagen (firewall, timers, servicios)
- `installer/` — cómo instalar en una VM de prueba o en el equipo real
- `scripts/` — provisión del día 1 (Tailscale, Kanidm, FreePBX); NO van en la imagen
- `docs/setup-guide.md` — **empieza por aquí**: guía paso a paso en lenguaje llano
- `docs/runbook.md` — operación diaria y qué hacer si algo se rompe

## Seguridad

Repo público a propósito: aquí solo hay configuración, jamás secretos.
Los secretos (claves, contraseñas) viven en GitHub Secrets, en el gestor de
contraseñas del administrador, o en el disco del servidor. Ver la tabla
completa en `docs/setup-guide.md`.
