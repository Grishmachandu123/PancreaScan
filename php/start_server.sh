#!/bin/bash
cd "$(dirname "$0")"
echo "Starting Local PHP Server on http://localhost:8000..."
echo "Press Ctrl+C to stop."
/Applications/XAMPP/xamppfiles/bin/php -S 0.0.0.0:8000 -t .
