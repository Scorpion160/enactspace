"""Check real DOM attachment, shadow roots and cancellation in a fresh browser."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browser', required=True)
    parser.add_argument('--bridge', type=Path)
    parser.add_argument('--engine', choices=['chromium', 'firefox'], default='chromium')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    bridge = (args.bridge or repo / 'frontend/web/enactmeet_bridge.js').resolve()
    browser = shutil.which(args.browser) or args.browser
    fixture = (repo / 'tools/fixtures/enactmeet_bridge_browser.html').read_text(encoding='utf-8')
    done = threading.Event()
    reports = []

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == '/bridge.js':
                content, kind = bridge.read_bytes(), 'application/javascript'
            elif self.path == '/':
                content = fixture.replace('__BRIDGE_URL__', '/bridge.js').encode('utf-8')
                kind = 'text/html; charset=utf-8'
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header('Content-Type', kind)
            self.send_header('Content-Length', str(len(content)))
            self.end_headers()
            self.wfile.write(content)

        def do_POST(self):
            length = int(self.headers.get('Content-Length', 0))
            if self.path != '/results' or not 0 < length < 65536:
                self.send_error(400)
                return
            reports.append(json.loads(self.rfile.read(length)))
            self.send_response(204)
            self.end_headers()
            done.set()

        def log_message(self, *args):
            pass

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f'http://127.0.0.1:{server.server_port}/'
    with tempfile.TemporaryDirectory(prefix='enactmeet-browser-', ignore_cleanup_errors=True) as directory:
        root = Path(directory)
        profile = root / 'profile'
        profile.mkdir()
        if args.engine == 'firefox':
            command = [browser, '--headless', '--no-remote', '--new-instance', '--profile', str(profile), url]
        else:
            command = [browser, '--headless=new', '--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage',
                '--no-first-run', '--no-default-browser-check', '--disable-background-networking',
                '--disable-component-update', '--disable-breakpad', '--disk-cache-size=1',
                '--media-cache-size=1', '--user-data-dir=' + str(profile), '--remote-debugging-port=0', url]
        process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            finished = done.wait(45)
            report = reports[-1] if finished and reports else {'passed': False, 'reason': 'Browser fixture did not finish'}
            print(json.dumps(report, ensure_ascii=False, indent=2))
            return 0 if report['passed'] else 1
        finally:
            if process.poll() is None:
                if os.name == 'nt':
                    subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True, timeout=15)
                else:
                    process.terminate()
                process.wait(timeout=15)
            server.shutdown()
            server.server_close()


if __name__ == '__main__':
    raise SystemExit(main())
