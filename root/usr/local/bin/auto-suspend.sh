#!/bin/sh

CRITICAL=10  # Critical battery percentage
SERVICE=auto-suspend

while read -r battery status capacity; do
  if [ "$status" = Charging -o "$capacity" -gt "$CRITICAL" ]; then
    logger "$SERVICE: Battery $battery $status at $capacity% capacity."
    exit 0
  fi
done <<< $(acpi -b | awk -F '[,:% ]' '{print $2, $4, $6}')

logger "$SERVICE: Critical battery threshold reached (<$CRITICAL%). Suspending."
systemctl suspend
