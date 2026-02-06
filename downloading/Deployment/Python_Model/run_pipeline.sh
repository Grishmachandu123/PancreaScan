#!/bin/bash

# Get directory of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Run the python script
echo "Starting training at $(date)"
# Check for python3 or python
if command -v python3 &>/dev/null; then
    python3 "$DIR/server_train.py"
else
    python "$DIR/server_train.py"
fi
echo "Finished at $(date)"
