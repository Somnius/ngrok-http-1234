# ngrok‑http‑1234

## What it does
The `ngrok-http-1234.sh` helper starts an **ngrok** tunnel that forwards traffic from a public URL to the local machine on port 1234. It also gives you convenient commands to check the status, stop the tunnel or copy the generated URL to your clipboard.

When you run it without arguments it:
1. Checks that `ngrok` is installed.
2. Starts `ngrok http 1234` in the background and records its PID.
3. Waits a few seconds for ngrok to create the public endpoint.
4. Prints the URL, a special *Cursor*‑API URL (the original URL with `/v1` appended) and some helpful instructions.
5. Copies the Cursor API URL to your clipboard if `wl-copy` is available.

If you pass one of the following options it performs a small helper action:
- `status` – shows whether ngrok is running, its PID and the current public URL.
- `stop`   – kills the background process and removes the PID file.
- `copy`   – copies the Cursor API URL to the clipboard without starting a new tunnel.

The script keeps two temporary files in `/tmp`: one for the PID (`/tmp/ngrok‑1234.pid`) and one for the log (`/tmp/ngrok‑1234.log`).

## How to use it
1. **Make sure ngrok is installed** – the script will exit with a helpful message if it isn’t.
2. Run the script:
   ```bash
   ./ngrok-http-1234.sh
   ```
3. After a few seconds you’ll see something like:
   ```text
   ngrok tunnel is running!
   URL: https://abcd1234.ngrok.io
   For Cursor IDE, use: https://abcd1234.ngrok.io/v1
   ```
   The Cursor‑API URL is automatically copied to your clipboard.
4. If you need the URL again later, just run:
   ```bash
   ./ngrok-http-1234.sh status
   ```
5. To stop the tunnel:
   ```bash
   ./ngrok-http-1234.sh stop
   ```
6. If you want to copy the URL without starting a new tunnel (e.g., after restarting your machine), use:
   ```bash
   ./ngrok-http-1234.sh copy
   ```

The script is intentionally simple and does not require any external dependencies beyond `ngrok` itself, `curl`, and optionally `wl-copy` for clipboard support.

