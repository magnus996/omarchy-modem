# Modem — Omarchy bar widget

Shows mobile broadband (5G/LTE) status from ModemManager in the Omarchy bar.

- Bar icon shows signal strength (0–3 bars); dimmed when not connected, crossed out when the radio is off or no modem is found.
- Left click opens a panel with operator, network type, signal, registration, connection and modem model.
- Right click (or the switch in the panel, or `c`/Enter) brings the NetworkManager GSM connection up or down. `r` refreshes.

Requires `ModemManager`, `NetworkManager` (with a `gsm` connection configured) and `jq`.

## Install

```bash
omarchy plugin add <repo-url> --enable
omarchy bar move magnushj.modem --section right --index 3
```

Settings: `refreshIntervalSec` (default 15).

IPC: `omarchy-shell magnushj.modem status|refresh|toggleConnection|open|close`.
