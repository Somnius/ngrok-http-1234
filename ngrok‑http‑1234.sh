#!/bin/bash

NGROK_PID_FILE="/tmp/ngrok-1234.pid"
NGROK_LOG="/tmp/ngrok-1234.log"

# Function to check if Cursor is running
check_cursor_running() {
    # Check for actual Cursor IDE process (not just any process with "cursor" in name)
    # Look for the main Cursor executable or processes in Cursor directory
    if pgrep -f "/usr/share/cursor/cursor" > /dev/null 2>&1 || \
       pgrep -f "/opt/cursor/cursor" > /dev/null 2>&1 || \
       pgrep -x "Cursor" > /dev/null 2>&1 || \
       pgrep -x "cursor" > /dev/null 2>&1; then
        return 0  # Cursor is running
    else
        return 1  # Cursor is not running
    fi
}

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

# Function to update Cursor API key
update_cursor_api_key() {
    local api_key="$1"
    
    if [ -z "$api_key" ]; then
        echo "❌ Error: API key is required"
        echo "Usage: $0 update-cursor-api-key <api-key>"
        return 1
    fi
    
    local db_path="$HOME/.config/Cursor/User/globalStorage/state.vscdb"
    
    if [ ! -f "$db_path" ]; then
        echo "❌ Error: Cursor database not found at $db_path"
        return 1
    fi
    
    # Check if sqlite3 is available
    if ! command -v sqlite3 &> /dev/null; then
        echo "❌ Error: sqlite3 is not installed"
        echo "   Install it with: sudo apt install sqlite3"
        return 1
    fi
    
    # Check if Cursor is running - must be closed for UI to update properly
    if check_cursor_running; then
        echo "❌ Error: Cursor IDE is currently running"
        echo ""
        echo "   Cursor must be closed before updating database values."
        echo "   The UI will not reflect changes if Cursor is running."
        echo ""
        echo "   Please close Cursor IDE and run this command again."
        return 1
    fi
    
    echo "Updating Cursor API key..."
    echo "  API Key: $api_key"
    echo ""
    
    # Use Python for proper error handling and locking
    python3 << PYTHON_EOF
import sqlite3
import sys
import os
import time

db_path = os.path.expanduser("$db_path")
api_key = "$api_key"
max_retries = 3
retry_delay = 0.5

for attempt in range(max_retries):
    try:
        conn = sqlite3.connect(db_path, timeout=5.0)
        cursor = conn.cursor()
        
        # Use BEGIN IMMEDIATE to get a write lock
        cursor.execute("BEGIN IMMEDIATE")
        
        # Update API Key
        cursor.execute("UPDATE ItemTable SET value = ? WHERE key = 'cursorAuth/openAIKey'", (api_key,))
        if cursor.rowcount > 0:
            print("✓ Updated API Key")
        else:
            # Insert if doesn't exist
            cursor.execute("INSERT INTO ItemTable (key, value) VALUES ('cursorAuth/openAIKey', ?)", (api_key,))
            print("✓ Inserted API Key")
        
        conn.commit()
        conn.close()
        print("")
        print("✓ Cursor API key updated successfully!")
        print("  You may need to restart Cursor for changes to take effect.")
        sys.exit(0)
        
    except sqlite3.OperationalError as e:
        if "database is locked" in str(e).lower() and attempt < max_retries - 1:
            print(f"⚠️  Database locked, retrying in {retry_delay}s... (attempt {attempt + 1}/{max_retries})")
            time.sleep(retry_delay)
            retry_delay *= 2  # Exponential backoff
            continue
        else:
            print(f"❌ Error updating database: {e}", file=sys.stderr)
            print("   Try closing Cursor IDE and running the command again.", file=sys.stderr)
            sys.exit(1)
    except Exception as e:
        print(f"❌ Error updating database: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)

print("❌ Failed to update after {max_retries} attempts", file=sys.stderr)
sys.exit(1)
PYTHON_EOF

    return $?
}

# Function to update Cursor base URL
update_cursor_base_url() {
    local url="$1"
    
    if [ -z "$url" ]; then
        # Try to get current ngrok URL if not provided
        if [ -f "$NGROK_PID_FILE" ]; then
            pid=$(cat "$NGROK_PID_FILE")
            if ps -p "$pid" > /dev/null 2>&1; then
                url=$(get_ngrok_url 0)
            fi
        fi
        
        if [ -z "$url" ]; then
            pid=$(pgrep -f "ngrok http 1234")
            if [ -n "$pid" ]; then
                url=$(get_ngrok_url 0)
            fi
        fi
        
        if [ -z "$url" ]; then
            echo "❌ Error: URL is required"
            echo "Usage: $0 update-cursor-base-url <url>"
            echo "   Or run this command while ngrok is running to use current URL"
            return 1
        fi
    fi
    
    local cursor_url="${url%/v1}"  # Remove /v1 if present, we'll add it
    cursor_url="${cursor_url}/v1"
    local db_path="$HOME/.config/Cursor/User/globalStorage/state.vscdb"
    
    if [ ! -f "$db_path" ]; then
        echo "❌ Error: Cursor database not found at $db_path"
        return 1
    fi
    
    # Check if Python 3 is available (needed for JSON manipulation)
    if ! command -v python3 &> /dev/null; then
        echo "❌ Error: python3 is not installed"
        echo "   Install it with: sudo apt install python3"
        return 1
    fi
    
    # Check if Cursor is running - must be closed for UI to update properly
    if check_cursor_running; then
        echo "❌ Error: Cursor IDE is currently running"
        echo ""
        echo "   Cursor must be closed before updating database values."
        echo "   The UI will not reflect changes if Cursor is running."
        echo ""
        echo "   Please close Cursor IDE and run this command again."
        return 1
    fi
    
    echo "Updating Cursor base URL..."
    echo "  Base URL: $cursor_url"
    echo ""
    
    # Create Python script to update the database
    python3 << PYTHON_EOF
import sqlite3
import json
import sys
import os
import time

db_path = os.path.expanduser("$db_path")
cursor_url = "$cursor_url"
max_retries = 3
retry_delay = 0.5

for attempt in range(max_retries):
    try:
        conn = sqlite3.connect(db_path, timeout=5.0)
        cursor = conn.cursor()
        
        # Use BEGIN IMMEDIATE to get a write lock
        cursor.execute("BEGIN IMMEDIATE")
        
        # Update Base URL
        storage_key = 'src.vs.platform.reactivestorage.browser.reactiveStorageServiceImpl.persistentStorage.applicationUser'
        cursor.execute("SELECT value FROM ItemTable WHERE key = ?", (storage_key,))
        row = cursor.fetchone()
        
        if row:
            data = json.loads(row[0])
            old_url = data.get("openAIBaseUrl", "Not set")
            data["openAIBaseUrl"] = cursor_url
            updated_json = json.dumps(data)
            cursor.execute("UPDATE ItemTable SET value = ? WHERE key = ?", (updated_json, storage_key))
            print(f"✓ Updated Base URL")
            print(f"  Old: {old_url}")
            print(f"  New: {cursor_url}")
        else:
            print("⚠️  Base URL storage key not found - creating new entry...")
            # Create minimal structure if it doesn't exist
            new_data = {"openAIBaseUrl": cursor_url}
            cursor.execute("INSERT INTO ItemTable (key, value) VALUES (?, ?)", 
                          (storage_key, json.dumps(new_data)))
            print("✓ Created Base URL entry")
        
        conn.commit()
        conn.close()
        print("")
        print("✓ Cursor base URL updated successfully!")
        print("  You may need to restart Cursor for changes to take effect.")
        sys.exit(0)
        
    except sqlite3.OperationalError as e:
        if "database is locked" in str(e).lower() and attempt < max_retries - 1:
            print(f"⚠️  Database locked, retrying in {retry_delay}s... (attempt {attempt + 1}/{max_retries})")
            time.sleep(retry_delay)
            retry_delay *= 2  # Exponential backoff
            continue
        else:
            print(f"❌ Error updating database: {e}", file=sys.stderr)
            print("   Try closing Cursor IDE and running the command again.", file=sys.stderr)
            sys.exit(1)
    except Exception as e:
        print(f"❌ Error updating database: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)

print(f"❌ Failed to update after {max_retries} attempts", file=sys.stderr)
sys.exit(1)
PYTHON_EOF

    return $?
}

# Function to update both Cursor API key and base URL
update_cursor() {
    local api_key="${1:-lm-studio}"  # Default to "lm-studio" if not provided
    local url="$2"
    
    # Check if Cursor is running - must be closed for UI to update properly
    if check_cursor_running; then
        echo "❌ Error: Cursor IDE is currently running"
        echo ""
        echo "   Cursor must be closed before updating database values."
        echo "   The UI will not reflect changes if Cursor is running."
        echo ""
        echo "   Please close Cursor IDE and run this command again."
        return 1
    fi
    
    # Get ngrok URL if not provided
    if [ -z "$url" ]; then
        echo "No URL provided, attempting to retrieve from running ngrok tunnel..."
        if [ -f "$NGROK_PID_FILE" ]; then
            pid=$(cat "$NGROK_PID_FILE")
            if ps -p "$pid" > /dev/null 2>&1; then
                url=$(get_ngrok_url 0)
            fi
        fi
        
        if [ -z "$url" ]; then
            pid=$(pgrep -f "ngrok http 1234")
            if [ -n "$pid" ]; then
                url=$(get_ngrok_url 0)
            fi
        fi
        
        if [ -z "$url" ]; then
            echo "❌ Error: Could not retrieve ngrok URL. Is ngrok running?"
            echo "   Start ngrok first: $0"
            echo "   Or provide URL manually: $0 update-cursor <api-key> <url>"
            return 1
        fi
        echo "  Using ngrok URL: $url"
    fi
    
    echo ""
    echo "Updating Cursor settings..."
    echo "  API Key: $api_key"
    echo "  Base URL: ${url}/v1"
    echo ""
    
    # Update API key
    if ! update_cursor_api_key "$api_key"; then
        echo "❌ Failed to update API key"
        return 1
    fi
    
    echo ""
    
    # Update base URL
    if ! update_cursor_base_url "$url"; then
        echo "❌ Failed to update base URL"
        return 1
    fi
    
    echo ""
    echo "✓ Cursor settings updated successfully!"
    echo "  API Key: $api_key"
    echo "  Base URL: ${url}/v1"
    echo ""
    echo "  Please restart Cursor IDE for changes to take effect."
    
    return 0
}

# Handle update-cursor command (convenience command to update both)
if [ "$1" == "update-cursor" ]; then
    update_cursor "$2" "$3"
    exit $?
fi

# Handle update-cursor-api-key command
if [ "$1" == "update-cursor-api-key" ]; then
    if [ -z "$2" ]; then
        echo "❌ Error: API key is required"
        echo "Usage: $0 update-cursor-api-key <api-key>"
        exit 1
    fi
    update_cursor_api_key "$2"
    exit $?
fi

# Handle update-cursor-base-url command
if [ "$1" == "update-cursor-base-url" ]; then
    update_cursor_base_url "$2"
    exit $?
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
    echo "  $0 status                - Show status and URL"
    echo "  $0 stop                  - Stop ngrok"
    echo "  $0 copy                  - Copy Cursor API URL to clipboard"
    echo "  $0 update-cursor [key] [url]  - Update both API key and base URL (defaults: lm-studio, current ngrok URL)"
    echo "  $0 update-cursor-api-key <key>  - Update Cursor API key in database"
    echo "  $0 update-cursor-base-url [url]  - Update Cursor base URL (uses current ngrok URL if not specified)"
else
    echo "⚠ Could not retrieve ngrok URL"
    echo "Check if ngrok is running: $0 status"
    echo "Check logs: tail -f $NGROK_LOG"
fi
