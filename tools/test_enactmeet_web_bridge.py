"""Check real DOM attachment, shadow roots and cancellation in a fresh browser."""
import argparse
import html
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browser', required=True)
    parser.add_argument('--bridge', type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    bridge = (args.bridge or repo / 'frontend/web/enactmeet_bridge.js').resolve()
    browser = shutil.which(args.browser) or args.browser
    fixture = (repo / 'tools/fixtures/enactmeet_bridge_browser.html').read_text(encoding='utf-8')
    with tempfile.TemporaryDirectory(prefix='enactmeet-browser-', ignore_cleanup_errors=True) as directory:
        root = Path(directory)
        page = root / 'check.html'
        page.write_text(fixture.replace('__BRIDGE_URL__', html.escape(bridge.as_uri(), quote=True)), encoding='utf-8')
        result = subprocess.run([
            browser, '--headless=new', '--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage',
            '--no-first-run', '--no-default-browser-check', '--disable-background-networking',
            '--disable-component-update', '--disable-breakpad', '--disk-cache-size=1',
            '--media-cache-size=1', '--user-data-dir=' + str(root / 'profile'),
            '--virtual-time-budget=15000', '--dump-dom', page.as_uri(),
        ], capture_output=True, timeout=90)
        output = result.stdout.decode('utf-8', errors='replace')
        match = re.search(r'<pre\b[^>]*\bid="enactmeet-test-results"[^>]*>(.*?)</pre>', output, re.S)
        if result.returncode or not match or not match[1].strip():
            print(json.dumps({'passed': False, 'reason': 'Browser fixture did not finish', 'returncode': result.returncode}))
            return 1
        report = json.loads(html.unescape(match[1]))
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
