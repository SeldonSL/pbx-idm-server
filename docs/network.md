# Red: dos sedes unidas por Tailscale

```
Sede A (donde vive el servidor)          Sede B
┌─────────────────────────────┐          ┌──────────────────────────┐
│ pbx-idm (este servidor)     │          │ subnet router Tailscale  │
│  · tailscale0 (tailnet)     │◄────────►│ (router OpenWrt, Pi, o   │
│  · NIC física → zona lan    │ internet │  mini equipo dedicado)   │
│ teléfonos IP → LAN directa  │          │ teléfonos IP → vía subnet│
└─────────────────────────────┘          └──────────────────────────┘
```

- **Sede A**: los teléfonos alcanzan el servidor por la LAN (el firewall solo
  les permite SIP/RTP, nada de administración).
- **Sede B**: los teléfonos IP físicos no pueden correr Tailscale, así que un
  dispositivo de la sede B actúa de *subnet router*: anuncia la LAN B a la
  tailnet y enruta el tráfico de los teléfonos hacia el servidor.

## Configurar el subnet router de la sede B (pendiente de hardware)

1. Instalar Tailscale en el dispositivo elegido.
2. `tailscale up --advertise-routes=192.168.B.0/24` (la LAN real de la sede B).
3. Aprobar la ruta en https://login.tailscale.com/admin/machines.
4. En los teléfonos de la sede B: servidor SIP = IP Tailscale del pbx-idm
   (100.x.x.x) o el FQDN MagicDNS si el router lo resuelve.
5. El servidor ya corre `tailscale up --accept-routes`, así que ve la LAN B.

## Plan futuro (decisión jul-2026): fonos físicos SOLO vía capa Tailscale

Cuando lleguen los teléfonos de escritorio, AMBAS sedes los conectarán detrás
de un subnet router y se cerrará SIP/RTP de la zona `lan`. Objetivo: la central
solo es alcanzable a través de la tailnet, independiente de la configuración
de los routers de cada sede (un port-forward/DMZ accidental deja de ser riesgo).

**Trampa conocida (sede A):** los fonos NO pueden compartir la subred del
servidor. Si un fono manda el registro por el túnel pero el servidor responde
directo por la LAN (son vecinos), el fono descarta la respuesta por venir de
otra IP (ruteo asimétrico). Los fonos de la sede A necesitan su PROPIA red
(VLAN de voz o un router en cascada, ej. 192.168.101.0/24), distinta de la
red del servidor.

Checklist del día que lleguen los fonos:
1. Crear la red de fonos de la sede A (VLAN o router en cascada).
2. Un subnet router por sede anunciando su red de fonos
   (`--advertise-routes=`). Si el subnet router ES el router de la red de
   fonos (ej. GL.iNet), no se necesitan rutas estáticas: los fonos lo usan
   de gateway y él mete el tráfico al túnel.
3. Aprobar rutas + deshabilitar key expiry de ambos en la consola Tailscale.
4. Agregar las redes de fonos a Local Networks en la GUI.
5. Fonos: servidor SIP = IP Tailscale del pbx-idm (100.x.x.x, estable).
6. Commit: quitar 5060 y 10000-20000 de `lan.xml` (41641/udp SE QUEDA: permite
   la conexión directa de los túneles; es WireGuard autenticado, riesgo nulo).
   Llega solo con el update de las 04:00.
7. Probar *43 desde un fono de cada sede y una llamada inter-sedes.

Hardware sugerido para subnet router: mini-router con Tailscale integrado
(GL.iNet con firmware 4.x, ej. Brume 2 / Beryl AX — se activa desde su GUI)
o una Raspberry Pi con tailscale. El ancho de banda de voz es trivial
(~0,1 Mbps por llamada): cualquier modelo sirve; importa que reciba updates.

## En FreePBX (Asterisk SIP Settings)

- Local Networks: `100.64.0.0/10` (rango Tailscale) + LAN A + LAN B.
- RTP Port Ranges: 10000-20000 (coincide con el firewall).
- Sin `external_media_address`: no hay NAT entre teléfonos y PBX (LAN directa
  o túnel Tailscale). Solo se tocará cuando se contrate la troncal SIP.

## Puertos expuestos (resumen del firewall)

| Interfaz | Permitido |
|---|---|
| NIC física (zona `lan`) | 5060 udp/tcp, 10000-20000/udp, 41641/udp |
| tailscale0 (zona `tailnet`) | lo anterior + 22, 80, 8443, 9090 |
| Todo lo demás | DROP |
