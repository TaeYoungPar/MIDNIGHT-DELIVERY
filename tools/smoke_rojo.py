"""Exercise the actual local Rojo handshake, then stop only the process we started."""
import json
import subprocess
import time
import urllib.request
from pathlib import Path

with Path('/tmp/midnight-rojo-smoke.log').open('w') as log:
    process = subprocess.Popen(['rojo', 'serve', 'default.project.json', '--port', '34873'], stdout=log, stderr=subprocess.STDOUT)
    try:
        client = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        last_error = None
        for attempt in range(50):
            if process.poll() is not None:
                raise RuntimeError('Rojo exited before becoming ready')
            try:
                with client.open('http://127.0.0.1:34873/api/rojo', timeout=1) as response:
                    data = json.load(response)
                assert data['serverVersion'].startswith('7.6.1'), data
                assert data['sessionId'], data
                print('PASS Rojo handshake: serverVersion=7.6.1, sessionId present')
                break
            except OSError as error:
                last_error = error
                time.sleep(0.1)
        else:
            raise RuntimeError(f'Rojo handshake not ready: {last_error}')
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
