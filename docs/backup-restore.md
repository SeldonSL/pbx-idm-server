# Backups y restauración

## Qué se respalda y cuándo (todo automático)

| Hora | Qué | Cómo | Dónde queda |
|---|---|---|---|
| 22:00 | BD de Kanidm | `[online_backup]` de server.toml (7 versiones) | `/var/lib/kanidm/data/backups` → copiado a `/var/backups/pbx-idm/kanidm` |
| 01:30 | FreePBX completo (BD + config) | módulo Backup de FreePBX (job manual día-1) | `/var/backups/pbx-idm/freepbx` (via bind mount) |
| 02:30 | /etc del nspawn + /etc/pbx-idm | `pbx-idm-backup.service` | `/var/backups/pbx-idm/etc` |

Rotación: 14 días. **Canario**: si un día no aparece backup nuevo, algo está mal.

## Restaurar

### FreePBX (en un nspawn recién provisionado)
```bash
sudo machinectl shell freepbx
fwconsole backup --restore /var/backups/host/<archivo>.tar.gz
fwconsole reload
```

### Kanidm
```bash
sudo systemctl stop kanidm
sudo podman run --rm -i -v /var/lib/kanidm/data:/data:Z \
  docker.io/kanidm/server:1.10.4 kanidmd restore /data/backups/<archivo>
sudo systemctl start kanidm
```

### Servidor completo (desastre total)
1. Reinstalar con `installer/` (30 min).
2. Correr los 3 scripts de provisión.
3. Restaurar FreePBX y Kanidm desde el último backup externo.

## Pendiente: destino remoto

Hoy los backups viven solo en el disco del servidor. Cuando haya destino
(otro equipo vía Tailscale, disco USB o nube), descomentar el bloque restic en
`system_files/usr/libexec/pbx-idm/backup.sh`. Mientras tanto, copia manual
ocasional desde tu desktop:
`scp -r core@pbx-idm.<tailnet>.ts.net:/var/backups/pbx-idm ~/respaldos-clinica/`
