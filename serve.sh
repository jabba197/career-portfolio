#!/bin/bash
# Quartz dev server with auto-restart on crash

while true; do
    echo "Starting Quartz server..."
    npx quartz build --serve
    exit_code=$?
    echo "Server exited with code $exit_code. Restarting in 1 second..."
    sleep 0.1
done
