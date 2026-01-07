#!/bin/bash

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

echo "Verifying Cursor database values..."
echo ""

# Check if Cursor is running
if check_cursor_running; then
    echo "❌ Error: Cursor IDE is currently running"
    echo ""
    echo "   Cursor must be closed before verifying database values."
    echo "   The UI may show stale cached values if Cursor is running."
    echo ""
    echo "   Please close Cursor IDE and run this script again."
    exit 1
fi

db_path="$HOME/.config/Cursor/User/globalStorage/state.vscdb"

if [ ! -f "$db_path" ]; then
    echo "❌ Database not found at $db_path"
    exit 1
fi

python3 << PYTHON_EOF
import sqlite3
import json
import os

db_path = os.path.expanduser("$db_path")

try:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check API Key
    print("1. API Key (cursorAuth/openAIKey):")
    cursor.execute("SELECT value FROM ItemTable WHERE key = 'cursorAuth/openAIKey'")
    row = cursor.fetchone()
    if row:
        print(f"   ✓ Found: {row[0]}")
    else:
        print("   ✗ Not found")
    
    # Check Base URL
    print("\n2. Base URL (openAIBaseUrl):")
    storage_key = 'src.vs.platform.reactivestorage.browser.reactiveStorageServiceImpl.persistentStorage.applicationUser'
    cursor.execute("SELECT value FROM ItemTable WHERE key = ?", (storage_key,))
    row = cursor.fetchone()
    if row:
        data = json.loads(row[0])
        base_url = data.get("openAIBaseUrl", "Not set")
        print(f"   ✓ Found: {base_url}")
    else:
        print("   ✗ Storage key not found")
    
    conn.close()
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_EOF

