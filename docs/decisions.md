# Registro de decisiones técnicas (ADRs)

## 1. Base: uCore minimal (no Bluefin, no FCOS puro)
`ghcr.io/ublue-os/ucore-minimal:stable` es la variante servidor del ecosistema
Universal Blue: trae Tailscale, podman, cockpit y firewalld preinstalados.
Bluefin es de escritorio; FCOS puro exigiría armar todo eso a mano.

## 2. Updates del SO con bootc a las 04:00 (no zincati, no rpm-ostree stage)
uCore deja los updates descargados pero sin reiniciar (sin ventana horaria).
Sustituimos por `bootc-fetch-apply-updates.timer` con `OnCalendar=04:00`:
aplica y reinicia solo si hay imagen nueva. Patrón usado por Bluefin.

## 3. FreePBX en systemd-nspawn (no imagen OCI)
No existe imagen OCI oficial; tiredofit/freepbx está archivada (jul 2025) y la
alternativa comunitaria (escomputers) es unipersonal. El instalador oficial de
Sangoma sobre Debian 12 en contenedor de sistema es la vía respaldada por la
comunidad (probada en LXC). Updates como manda el proyecto: apt + fwconsole.
**Plan B si nspawn+SELinux da fricción insalvable**: quadlet rootful
`Network=host` con `docker.io/escomputers/freepbx`.

## 4. FreePBX con red del host
Publicar 10.000 puertos RTP en modo bridge es inviable y el NAT causa audio
unidireccional. Con `VirtualEthernet=no` Asterisk ve las interfaces reales y
firewalld del host filtra.

## 5. Kanidm con tag exacto + AutoUpdate=registry
El tag exacto (`:1.10.4`) hace que el auto-update nocturno solo tome rebuilds
de parche del mismo tag. Los saltos de versión son un commit (quedan en el
historial y `bootc rollback` los revierte junto con el SO).

## 6. Dominio de Kanidm = FQDN de Tailscale (decisión PERMANENTE)
`pbx-idm.<tailnet>.ts.net` con certificados `tailscale cert` (Let's Encrypt).
Cero dependencias externas (no requiere dominio propio ni API de DNS), a cambio
de quedar atado al tailnet actual. El domain de Kanidm es muy difícil de
cambiar: si algún día se migra de Tailscale, se migra Kanidm con export/import.

## 7. Repo público
Estándar Universal Blue: GHCR gratis, sin token de pull en el servidor.
Consecuencia: disciplina estricta de secretos (ver tabla en setup-guide.md)
y nombres genéricos (sin datos del negocio en el repo).

## 8. Backups locales con estructura restic-ready
Decisión temporal del usuario (jul 2026). El árbol único /var/backups/pbx-idm
permite activar restic hacia cualquier destino descomentando un bloque.
