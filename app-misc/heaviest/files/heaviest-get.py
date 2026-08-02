#!/usr/bin/env python3

# Copyright 2025-2026 Anoncheg1
# Distributed under the terms of the GNU Affero General Public License v3.0 (AGPL-3.0)

import os
import glob
import sys
from collections import defaultdict
from pathlib import Path

# --- Configuration & Setup ---
DEBUG = "--debug" in sys.argv

# Note on Weighting:
# The original WEIGHT_MULTIPLIER was removed because dividing every weight by X
# and then dividing the final sum by the total weight (which is also divided by X)
# results in the exact same number. It was mathematically neutral.
# Current logic uses a linear decay: Newest file gets highest weight.

# Get all snapshot files sorted alphabetically (which matches chronological order due to 01, 02 naming)
files = sorted(glob.glob('/tmp/top_procs/top_procs_*'))

cpu_sum = defaultdict(float) # Stores the total weighted CPU time for each process
wt_sum = 0.0                 # Stores the sum of all weights used for normalization
lfs = len(files)             # Total number of files available

if lfs == 0:
    print("No data files found.")
    sys.exit(0)

# --- Processing Loop ---
for idx, file_path in enumerate(files):
    # Calculate weight:
    # idx=0 is the newest file (top_procs_01).
    # We want newer files to contribute more to the average.
    # Formula: Newest file gets weight 'lfs', oldest gets '1'.
    weight = lfs - idx

    wt_sum += weight

    if DEBUG:
        print(f'Processing {Path(file_path).name} (idx={idx}) with weight {weight}')

    try:
        # Skip empty files to avoid unnecessary processing
        if os.path.getsize(file_path) == 0:
            continue

        with open(file_path, 'r') as f:
            for line in f:
                # line.split() is implemented in C and is much faster than re.split()
                # Since the bash script now only outputs 2 columns, this is very efficient.
                parts = line.split()

                if len(parts) >= 2:
                    try:
                        cpu = float(parts[0]) # Column 1: %CPU
                        proc = parts[1]       # Column 2: COMMAND

                        # Accumulate the weighted CPU usage for this specific process
                        cpu_sum[proc] += cpu * weight

                        if DEBUG:
                            print(f'  -> {proc}: CPU={cpu}, Weighted Add={cpu * weight:.2f}')
                    except ValueError:
                        # Skip lines that don't contain valid numbers
                        continue
    except Exception as e:
        if DEBUG:
            print(f'Error processing file {file_path}: {e}')

# --- Final Calculation & Output ---
if "--help" in sys.argv:
    print("Usage: heaviest-get.py [--debug] [--help]")
    print("Calculates the heaviest recent CPU process based on a rolling 30-snapshot history.")
    sys.exit(0)

max_proc = ''
max_val = 0.0

# Iterate through all accumulated processes to find the one with the highest weighted average
for proc, sum_val in cpu_sum.items():
    # Normalize the sum by the total weight to get the actual average percentage
    avg = sum_val / wt_sum

    if DEBUG:
        print(f'Proc: {proc} | Weighted Sum: {sum_val:.2f} | Avg: {avg:.2f}%')

    if avg > max_val:
        max_val = avg
        max_proc = proc

if not max_proc:
    print("No processes found.")
    sys.exit(0)

# --- Name Cleaning ---
# Kernel threads often look like [kworker/0:1]. We remove slashes for cleaner output.
if max_proc.startswith('['):
    max_proc = max_proc.replace('/', '')
else:
    # For regular programs, extract just the executable name from the full path
    # e.g., /usr/bin/python3.10 -> python3.10
    max_proc = Path(max_proc).name

if DEBUG:
    print('===========================================')

# Output format: "process_name average_cpu%"
print(f'{max_proc} {max_val:.2f}%')
