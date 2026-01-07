# ngrok-http-1234

## What it does
The `ngrok-http-1234.sh` script manages an ngrok HTTP tunnel that forwards traffic from a public URL to localhost port 1234. It provides commands to start, stop, check status, and automatically update Cursor IDE settings with the tunnel URL and API key.

## Repository
This script lives in its own GitHub repository: https://github.com/Somnius/ngrok-http-1234. Feel free to fork or contribute if you find it useful.

## Basic usage

When run without arguments, the script:
1. Checks that ngrok is installed (exits with installation instructions if not found)
2. Starts ngrok http 1234 in the background and records its PID
3. Waits a few seconds for ngrok to initialize and create the public endpoint
4. Displays the public URL and Cursor API URL (with /v1 suffix)
5. Copies the Cursor API URL to clipboard if wl-copy is available

The script stores two temporary files in /tmp:
- `/tmp/ngrok-1234.pid` - process ID of the running ngrok instance
- `/tmp/ngrok-1234.log` - ngrok output log

## Commands

**status** - Shows whether ngrok is running, its PID, and the current public URL
```bash
./ngrok-http-1234.sh status
```

**stop** - Kills the background ngrok process and removes the PID file
```bash
./ngrok-http-1234.sh stop
```

**copy** - Copies the Cursor API URL to clipboard without starting a new tunnel
```bash
./ngrok-http-1234.sh copy
```

**update-cursor** - Updates both the API key and base URL in Cursor's database
```bash
./ngrok-http-1234.sh update-cursor [api-key] [url]
```
- If api-key is not provided, defaults to "lm-studio"
- If url is not provided, automatically retrieves the current ngrok URL
- Requires Cursor IDE to be closed before running
- Example: `./ngrok-http-1234.sh update-cursor` (uses defaults)
- Example: `./ngrok-http-1234.sh update-cursor "your-key"` (custom key, auto URL)
- Example: `./ngrok-http-1234.sh update-cursor "your-key" "https://example.ngrok-free.app"` (both custom)

**update-cursor-api-key** - Updates only the API key in Cursor's database
```bash
./ngrok-http-1234.sh update-cursor-api-key <api-key>
```
- Requires Cursor IDE to be closed before running

**update-cursor-base-url** - Updates only the base URL in Cursor's database
```bash
./ngrok-http-1234.sh update-cursor-base-url [url]
```
- If url is not provided, automatically retrieves the current ngrok URL
- Requires Cursor IDE to be closed before running

## Cursor integration

The script can programmatically update Cursor IDE settings stored in its SQLite database. Cursor stores these values in:
- Database: `~/.config/Cursor/User/globalStorage/state.vscdb`
- API Key: stored in `ItemTable` with key `cursorAuth/openAIKey`
- Base URL: stored in `ItemTable` with key `src.vs.platform.reactivestorage.browser.reactiveStorageServiceImpl.persistentStorage.applicationUser` as JSON with field `openAIBaseUrl`

Important notes:
- Cursor IDE must be completely closed before running update commands
- The script checks if Cursor is running and will refuse to update if it detects the process
- Values are stored as plain text (hex-encoded for API key, JSON for base URL)
- After updating, restart Cursor IDE for changes to take effect in the UI

## Dependencies

Required:
- ngrok (the script provides installation instructions if missing)
- curl (for retrieving ngrok API information)
- sqlite3 (for database updates, installed via system package manager)
- python3 (for JSON manipulation in database updates)

Optional:
- wl-copy (for Wayland clipboard support, install via `sudo apt install wl-clipboard`)
