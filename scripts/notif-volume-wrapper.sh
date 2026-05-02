#!/usr/bin/env bash

# Path to the "mute" flag file
MUTE_FLAG="$HOME/.config/swaync/notification-alerts/mute-flag"

# If the mute flag exists, exit the script immediately
if [ -f "$MUTE_FLAG" ]; then
    exit 0
fi

# Configuration
PATH_TO_SOUND="$1"
REDUCED_VOL="60%"  # Volume for background apps (lower than before for better contrast)
RESTORE_VOL="100%" 

# 1. Start playing the sound in the background immediately
# We use 'canberra-gtk-play' or 'paplay' with a specific process name we can identify
# Here we use paplay and set a specific property so we can find it
paplay --property=media.role=notification --property=application.name=SwayNC-Alert "$PATH_TO_SOUND" &
PLAY_PID=$!

# 2. Identify all audio streams EXCEPT our notification
# This looks for all sink-input IDs that do NOT have the name "SwayNC-Alert"
SINK_INPUTS=$(pactl list sink-inputs | grep -E "Sink Input #|application.name =" | \
    awk '/Sink Input #/ {id=$3} /application.name =/ {if ($0 !~ /SwayNC-Alert/) print id}')

# 3. Muffle the background apps
for ID in $SINK_INPUTS; do
    pactl set-sink-input-volume "${ID//\#/}" "$REDUCED_VOL"
done

# 4. Wait for the notification sound to finish
wait $PLAY_PID

# 5. Restore volume for the background apps
for ID in $SINK_INPUTS; do
    pactl set-sink-input-volume "${ID//\#/}" "$RESTORE_VOL"
done