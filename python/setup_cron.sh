#!/bin/bash

# Get absolute path to the training script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WRAPPER_SCRIPT="$SCRIPT_DIR/run_training.sh"

# Ensure wrapper is executable
chmod +x "$WRAPPER_SCRIPT"

# Cron Schedule: 0 0 1 * * (At 00:00 on day-of-month 1)
CRON_JOB="0 0 1 * * $WRAPPER_SCRIPT"

# Backup current crontab
crontab -l > mycron.backup 2>/dev/null

# Check if job already exists
if grep -q "$WRAPPER_SCRIPT" mycron.backup; then
    echo "⚠️  Cron job already exists for this script."
else
    # Append job to current crontab
    echo "$CRON_JOB" >> mycron.backup
    
    # Install new crontab
    crontab mycron.backup
    echo "✅ Successfully scheduled monthly training (1st of every month)."
    echo "   Command: $CRON_JOB"
fi

rm mycron.backup
