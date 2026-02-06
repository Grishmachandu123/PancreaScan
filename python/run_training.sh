#!/bin/bash

# Navigate to the script's directory (php_api)
cd "$(dirname "$0")"

# Log start time
echo "------------------------------------------------" >> training.log
echo "Starting Monthly Training at $(date)" >> training.log

# Run the Python training script
# Ensure python3 is in path or use full path if needed. 
python3 server_train.py >> training.log 2>&1

# Log completion
echo "Training finished at $(date)" >> training.log
echo "------------------------------------------------" >> training.log
