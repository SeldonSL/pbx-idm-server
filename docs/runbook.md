# Runbook: operación diaria y emergencias

## Acceso normal

- SSH: `ssh core@pbx-idm.<tailnet>.ts.net` (solo desde equipos en la tailnet)
- FreePBX: `https://pbx-idm.<tailnet>.ts.net` · Kanidm: `https://...:8443` · Cockpit: `https://...:9090`

## Cambiar configuración del sistema

No se edita el servidor: se edita este repo y se hace push. El cambio llega
solo a las 04:00 (o inmediato con `sudo bootc update --apply` por SSH).

## "Algo se rompió después de la madrugada"

```bash
ssh core@pbx-idm.<tailnet>.ts.net
sudo bootc rollback && sudo systemctl reboot   # vuelve a la imagen de ayer
```
Los datos no se pierden (viven en /var, fuera de la imagen). Para volver a una
fecha específica: `sudo bootc switch ghcr.io/seldonsl/pbx-idm-server:stable-AAAAMMDD`.

## "No puedo entrar por Tailscale"

1. Teclado y monitor al mini PC → login `core` + contraseña de rescate (gestor).
2. `sudo systemctl status tailscaled` / `sudo tailscale up` de nuevo.
3. Emergencia extrema (abrir SSH por LAN temporalmente, se cierra al reiniciar):
   `sudo firewall-cmd --zone=lan --add-service=ssh`

## Chequeos rápidos

```bash
systemctl list-timers                        # deben aparecer 02:30 / 03:30 / 04:00
sudo machinectl list                         # freepbx RUNNING
systemctl status kanidm systemd-nspawn@freepbx
sudo bootc status                            # qué imagen corre y cuál está staged
systemd-cgtop                                # consumo de RAM por servicio
ls -lt /var/backups/pbx-idm/*/ | head        # backups recientes (canario de salud)
sudo openssl x509 -enddate -noout -in /var/lib/kanidm/data/tls/fullchain.pem
```

## Dentro de FreePBX (cuando haga falta)

```bash
sudo machinectl shell freepbx                # entrar al mini-Debian
asterisk -rx "pjsip show contacts"           # teléfonos registrados
asterisk -rx "pjsip show channelstats"       # calidad de llamadas en curso
fwconsole reload                             # aplicar config
```

## Subir de versión Kanidm (deliberado)

1. Editar `system_files/usr/share/containers/systemd/kanidm.container` (el tag).
2. Leer las release notes de Kanidm (pueden traer pasos de upgrade).
3. Push → llega a las 04:00. El backup de las 22:00 sirve de red de seguridad.
