#!/bin/bash
# Prints one JSON line describing the first ModemManager modem and its NetworkManager connection.
modem=$(mmcli -L -J 2>/dev/null | jq -r '.["modem-list"][0] // empty')
conn=$(nmcli -t -f NAME,TYPE con show 2>/dev/null | awk -F: '$2=="gsm"{print $1; exit}')
active=$(nmcli -t -f NAME,TYPE con show --active 2>/dev/null | awk -F: '$2=="gsm"{print "true"; exit}')

if [ -z "$modem" ]; then
  jq -cn --arg conn "$conn" '{present:false, connection:$conn, connectionActive:false}'
  exit 0
fi

mmcli -m "$modem" -J 2>/dev/null | jq -c --arg conn "$conn" --argjson active "${active:-false}" '
  .modem as $m | {
    present: true,
    model: $m.generic.model,
    state: $m.generic.state,
    power: $m.generic["power-state"],
    signal: (($m.generic["signal-quality"].value // "0") | tonumber),
    tech: ($m.generic["access-technologies"] // []),
    operator: ($m["3gpp"]["operator-name"] // ""),
    registration: ($m["3gpp"]["registration-state"] // ""),
    connection: $conn,
    connectionActive: $active
  }'
