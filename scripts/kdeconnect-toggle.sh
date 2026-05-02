#!/usr/bin/env bash

# If the settings window is open, close it. 
# If not, open the settings window.
if pgrep -x "kdeconnect-app" > /dev/null; then
    pkill kdeconnect-app
else
    kdeconnect-app &
fi