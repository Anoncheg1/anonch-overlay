#!/bin/bash

# Copyright 2025-2026 Anoncheg1
# Distributed under the terms of the GNU Affero General Public License v3.0 (AGPL-3.0)

# --- Configuration ---
LOG_DIR="/tmp/top_procs"
MAX_FILES=30 # Number of historical snapshots to keep

# for Gentoo daemon:
cleanup() {
    echo "Shutting down heaviest-cpu-daemon..."
    exit 0
}

trap cleanup SIGTERM SIGINT


# Ensure the directory exists; -p prevents errors if it already exists
mkdir -p "$LOG_DIR"

# Clean up any leftover files from previous runs to ensure a fresh start
rm -f "$LOG_DIR"/top_procs_* &>/dev/null

while true; do
    # --- Step 1: File Rotation ---
    # We iterate backward (from MAX_FILES-1 down to 1) to avoid overwriting
    # a file before we've had a chance to move it.
    # Example: Move 29->30, then 28->29, etc.
    for (( n=MAX_FILES-1; n>=1; n-- )); do
        # Use printf to ensure consistent 2-digit formatting (e.g., 01, 02)
        src=$(printf "%02d" "$n")
        dst=$(printf "%02d" "$((n+1))")

        # Only attempt to move if the source file actually exists
        [ -f "$LOG_DIR/top_procs_$src" ] && mv "$LOG_DIR/top_procs_$src" "$LOG_DIR/top_procs_$dst"
    done

    # --- Step 2: Data Collection ---
    # top -bn1: Batch mode, 1 iteration (non-interactive)
    # -c: Show full command path
    # -o +%CPU: Sort by CPU usage descending

    # awk 'NR>7': Skips the first 7 lines of 'top' output (headers/summary).
    # $9>0.0: Filters out processes using 0% CPU to save space.
    # !/heaviest.../: Excludes our own daemon to prevent feedback loops.
    # {print $9, $12}: Extracts ONLY the %CPU column and the COMMAND column.
    # This reduces disk I/O significantly compared to saving the whole line.
    # top -bn1 -c -o +%CPU | awk 'NR>7 && $9>0.0 && !/heaviest-cpu-daemon/ && !/top -bn1/ {print $9, $12}' > "$LOG_DIR/top_procs_01"
    top -bn1 -c -o +%CPU -w 512 | awk 'NR>7 && $9>0.0 && !/heaviest-cpu-daemon/ && !/top -bn1/ {cmd=$12; sub(/.*\//, "", cmd); print $9, cmd, $13}' > "$LOG_DIR/top_procs_01"

    # --- Step 3: Interval ---
    sleep 2
done
