#!/bin/bash

# ============================================================================
# ChirpStack Export - Automatic Cron Setup Script
# ============================================================================

SCRIPT_DIR="/home/ubuntu/sharepoint-api"
SCRIPT_PATH="$SCRIPT_DIR/lns-api.sh"
LOG_FILE="/var/log/chirpstack_export.log"
CRON_SCHEDULE="*/15 * * * *"

echo "=============================================="
echo "ChirpStack Export - Cron Job Setup"
echo "=============================================="
echo ""

# Check if script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Error: Script not found at $SCRIPT_PATH"
    exit 1
fi

# Make script executable
chmod +x "$SCRIPT_PATH"
echo "✓ Made script executable"

# Create log file
if [ ! -f "$LOG_FILE" ]; then
    sudo touch "$LOG_FILE"
    sudo chown $USER:$USER "$LOG_FILE"
    echo "✓ Created log file: $LOG_FILE"
else
    echo "✓ Log file already exists: $LOG_FILE"
fi

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
    echo ""
    echo "⚠️  Cron job already exists!"
    echo ""
    read -p "Do you want to replace it? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove old cron job
        crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab -
        echo "✓ Removed old cron job"
    else
        echo "Keeping existing cron job"
        exit 0
    fi
fi

# Add cron job
(crontab -l 2>/dev/null; echo "$CRON_SCHEDULE $SCRIPT_PATH >> $LOG_FILE 2>&1") | crontab -
echo "✓ Added cron job to crontab"

# Verify cron service is running
if systemctl is-active --quiet cron 2>/dev/null || systemctl is-active --quiet crond 2>/dev/null; then
    echo "✓ Cron service is running"
else
    echo "⚠️  Starting cron service..."
    sudo systemctl start cron 2>/dev/null || sudo systemctl start crond 2>/dev/null
    sudo systemctl enable cron 2>/dev/null || sudo systemctl enable crond 2>/dev/null
    echo "✓ Cron service started and enabled"
fi

echo ""
echo "=============================================="
echo "✅ Setup Complete!"
echo "=============================================="
echo ""
echo "📋 Cron Job Details:"
echo "  Schedule: Every 15 minutes"
echo "  Script: $SCRIPT_PATH"
echo "  Log: $LOG_FILE"
echo ""
echo "🔍 Verify installation:"
echo "  crontab -l"
echo ""
echo "📊 View logs:"
echo "  tail -f $LOG_FILE"
echo ""
echo "⏱️  Next run: $(date -d '+15 minutes' '+%Y-%m-%d %H:%M')"
echo ""
echo "🧪 Test now:"
echo "  $SCRIPT_PATH"
echo ""

# Optionally run test
read -p "Do you want to run a test now? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🧪 Running test export..."
    echo "=============================================="
    $SCRIPT_PATH
fi

echo ""
echo "✅ All done! Your exports will run every 15 minutes."