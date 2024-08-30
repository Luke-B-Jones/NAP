#!/bin/bash

# Adjusting for light usage
cores=$(echo "scale=0; $all_cores * 0.45 / 1" | bc)
RAM=$(echo "scale=0; $all_RAM * 0.45 / 1" | bc)
Q_cores=$((cores / 2))
if [ "$Q_cores" -lt 2 ]; then
    Q_cores=2
fi
memory_per_core=$(echo "scale=0; ${RAM} / ${cores}" | bc)

# Calculate half of RAM and cores
para_RAM=$(echo "($RAM / 2 + 1) / 2 * 2" | bc) # Round up to nearest even number, minimum 5GB
para_cores=$(echo "($cores / 2 + 1) / 2 * 2" | bc) # Round up to nearest even number, minimum 2

# Ensure para_RAM is at least 5GB
if [ "$para_RAM" -lt 5 ]; then
    para_RAM=5
fi

# Ensure para_cores is at least 2
if [ "$para_cores" -lt 2 ]; then
    para_cores=2
fi

export cores
export RAM
export Q_cores
export memory_per_core
export para_RAM
export para_cores

