#!/bin/bash

NGROK_PID_FILE="/tmp/ngrok-1234.pid"
NGROK_LOG="/tmp/ngrok-1234.log"

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ Error: ngrok is not installed"
    echo ""
    echo "Please install ngrok first:"
    echo ""
    echo "  Option 1: Using official ngrok repository (recommended):"
    echo "    curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \\"
    echo "      | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \\"
    echo "      && echo \"deb https://ngrok-agent.s3.amazonaws.com bookworm main\" \\"
    echo "      | sudo tee /etc/apt/sources.list.d/ngrok.list \\"
    echo "      && sudo apt update \\"
    echo "      && sudo apt install ngrok"
    echo ""
    echo "  Option 2: Download binary manually:"
    echo "    Visit: https://ngrok.com/download"
    echo ""
    echo "  Option 3: Using snap (if available):"
    echo "    sudo snap install ngrok"
    echo ""
    exit 1
fi

# Function to get ngrok URL
get_ngrok_url() {
    local wait_time=${1:-0}  # Optional wait time parameter
    if [ "$wait_time" -gt 0 ]; then
        sleep "$wait_time"
    fi
    local url=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o 'https://[^"]*\.ngrok[^"]*' | head -1)
    echo "$url"
}

# Function to copy to clipboard
copy_to_clipboard() {
    local text="$1"
    if command -v wl-copy &> /dev/null; then
        echo -n "$text" | wl-copy
        echo "✓ Copied to clipboard (Wayland)"
        return 0
    else
        echo "⚠ wl-copy not found"
        echo "   Install it with: sudo apt install wl-clipboard"
        return 1
    fi
}


# Function to show status
show_status() {
    if [ -f "$NGROK_PID_FILE" ]; then
        local pid=$(cat "$NGROK_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Status: Running (PID: $pid)"
            local url=$(get_ngrok_url 0)  # No wait for status check
            if [ -n "$url" ]; then
                echo "URL: $url"
                echo "Cursor URL: ${url}/v1"
                echo "Inspect requests: http://127.0.0.1:4040/inspect/http"
            else
                echo "URL: Not available yet (ngrok may still be initializing)"
            fi
        else
            echo "Status: Not running (stale PID file)"
            rm -f "$NGROK_PID_FILE"
        fi
    else
        echo "Status: Not running"
    fi
}

# Function to stop ngrok
stop_ngrok() {
    if [ -f "$NGROK_PID_FILE" ]; then
        local pid=$(cat "$NGROK_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            kill "$pid" 2>/dev/null
            sleep 1
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null
            fi
            echo "✓ Stopped ngrok (PID: $pid)"
        else
            echo "⚠ Process not found (stale PID file)"
        fi
        rm -f "$NGROK_PID_FILE"
    else
        # Try to find and kill any ngrok process on port 1234
        local pid=$(pgrep -f "ngrok http 1234")
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null
            echo "✓ Stopped ngrok (PID: $pid)"
        else
            echo "⚠ No ngrok process found"
        fi
    fi
}

# Handle stop command
if [ "$1" == "stop" ]; then
    stop_ngrok
    exit 0
fi

# Handle status command
if [ "$1" == "status" ]; then
    show_status
    exit 0
fi

# Handle copy command
if [ "$1" == "copy" ]; then
    # Check if ngrok is running
    if [ -f "$NGROK_PID_FILE" ]; then
        pid=$(cat "$NGROK_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            url=$(get_ngrok_url 0)  # No wait for copy command
            if [ -n "$url" ]; then
                cursor_url="${url}/v1"
                if copy_to_clipboard "$cursor_url"; then
                    echo "URL copied: $cursor_url"
                    exit 0
                else
                    exit 1
                fi
            else
                echo "⚠ Could not retrieve ngrok URL"
                echo "ngrok may still be initializing. Try again in a moment."
                exit 1
            fi
        else
            echo "⚠ ngrok is not running (stale PID file)"
            rm -f "$NGROK_PID_FILE"
            echo "Start it first: $0"
            exit 1
        fi
    else
        # Try to find ngrok process even without PID file
        pid=$(pgrep -f "ngrok http 1234")
        if [ -n "$pid" ]; then
            url=$(get_ngrok_url 0)
            if [ -n "$url" ]; then
                cursor_url="${url}/v1"
                if copy_to_clipboard "$cursor_url"; then
                    echo "URL copied: $cursor_url"
                    exit 0
                else
                    exit 1
                fi
            else
                echo "⚠ Could not retrieve ngrok URL"
                exit 1
            fi
        else
            echo "⚠ ngrok is not running"
            echo "Start it first: $0"
            exit 1
        fi
    fi
fi


# Check if ngrok is already running
if [ -f "$NGROK_PID_FILE" ]; then
    pid=$(cat "$NGROK_PID_FILE")
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "⚠ ngrok is already running (PID: $pid)"
        echo "Use '$0 stop' to stop it first"
        show_status
        exit 1
    else
        rm -f "$NGROK_PID_FILE"
    fi
fi

# Start ngrok in background
echo "Starting ngrok http tunnel on port 1234..."
nohup ngrok http 1234 > "$NGROK_LOG" 2>&1 &
NGROK_PID=$!
echo "$NGROK_PID" > "$NGROK_PID_FILE"

echo "Waiting for ngrok to initialize..."
sleep 5

# Get the URL (with wait time for initial startup)
NGROK_URL=$(get_ngrok_url 3)

if [ -n "$NGROK_URL" ]; then
    CURSOR_URL="${NGROK_URL}/v1"
    echo ""
    echo "=========================================="
    echo "ngrok tunnel is running!"
    echo "URL: $NGROK_URL"
    
    echo "=========================================="
    echo ""
    echo "For Cursor IDE, use: $CURSOR_URL"
    echo ""
    
    # Copy to clipboard
    if copy_to_clipboard "$CURSOR_URL" 2>/dev/null; then
        echo ""
    fi
    
    echo "⚠ IMPORTANT: Manually update Cursor IDE settings:"
    echo "   1. Open Cursor Settings (Ctrl+,)"
    echo "   2. Go to Models section"
    echo "   3. Toggle ON 'Override OpenAI Base URL'"
    echo "   4. Paste the URL above: $CURSOR_URL"
    echo ""
    
    echo "PID: $NGROK_PID (saved to $NGROK_PID_FILE)"
    echo "Log: $NGROK_LOG"
    echo "Inspect requests: http://127.0.0.1:4040/inspect/http"
    echo ""
    echo "Commands:"
    echo "  $0 status  - Show status and URL"
    echo "  $0 stop    - Stop ngrok"
    echo "  $0 copy    - Copy Cursor API URL to clipboard"
else
    echo "⚠ Could not retrieve ngrok URL"
    echo "Check if ngrok is running: $0 status"
    echo "Check logs: tail -f $NGROK_LOG"
fi
