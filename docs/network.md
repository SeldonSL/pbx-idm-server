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
