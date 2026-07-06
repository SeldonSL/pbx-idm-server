# Kanidm: gestión de usuarios del día a día

Kanidm queda instalado y vacío tras el deploy. Este documento cubre cómo cargar
al personal y operarlo. Todo se hace desde un equipo en la tailnet.

## Cuentas de administración (del gestor de contraseñas)

| Cuenta | Para qué | Frecuencia |
|---|---|---|
| `admin` | Configurar el servidor Kanidm e integraciones | Rara vez |
| `idm_admin` | Crear/gestionar personas y grupos | Día a día |

## CLI desde el desktop (una vez)

```bash
mkdir -p ~/.config/kanidm-cli
echo 'uri = "https://pbx-idm.<tailnet>.ts.net:8443"' > ~/.config/kanidm-cli/config
alias kanidm='podman run --rm -it -v ~/.config/kanidm-cli:/root/.config/kanidm:Z docker.io/kanidm/tools:1.10.4 kanidm'
# (el alias puede ir en ~/.bashrc; mantener el tag alineado con el del quadlet)
```

## Operaciones frecuentes

```bash
kanidm login -D idm_admin

# grupos por rol (los permisos de las apps futuras se dan por grupo)
kanidm group create veterinarios
kanidm group create recepcion

# alta de una persona
kanidm person create mgonzalez "María González"
kanidm group add-members veterinarios mgonzalez

# enrolamiento: genera un LINK de un solo uso; la persona lo abre (en la
# tailnet) y registra su credencial — passkey recomendado
kanidm person credential create-reset-token mgonzalez

# otros habituales
kanidm person get mgonzalez
kanidm group list-members veterinarios
kanidm person credential create-reset-token mgonzalez   # si perdio su credencial
```

Autoservicio: cada persona gestiona sus credenciales en
`https://pbx-idm.<tailnet>.ts.net:8443` (su panel personal).

## Nota sobre acceso

Todo requiere estar en la tailnet: para que el personal use Kanidm desde sus
equipos/telefonos, esos dispositivos deben tener Tailscale (o estar detras del
subnet router de su sede — ver network.md).

## Integraciones futuras (cuando se necesiten)

- **OIDC** para aplicaciones web propias (Django: mozilla-django-oidc) — login
  unico con las cuentas de la clinica.
- **LDAPS** (puerto 3636, hoy deshabilitado en server.toml) para software legado.
- **RADIUS** (imagen kanidm/radius) para autenticar el WiFi de la clinica.

Cada una se documenta como ADR en decisions.md cuando se implemente.
