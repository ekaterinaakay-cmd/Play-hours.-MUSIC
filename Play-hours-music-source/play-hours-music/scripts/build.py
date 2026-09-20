"""Example: python scripts/build.py android"""
from pathlib import Path
import json
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
platform = sys.argv[1] if len(sys.argv) > 1 else ''
if platform not in ('android', 'windows', 'ios'):
    raise SystemExit('Choose android, windows or ios.')
config = root / 'config.json'
if not config.exists():
    raise SystemExit('Copy config.example.json to config.json and enter your Supabase public settings.')
data = json.loads(config.read_text())
if not data.get('SUPABASE_URL', '').startswith('https://') or not data.get('SUPABASE_ANON_KEY'):
    raise SystemExit('Configure SUPABASE_URL and SUPABASE_ANON_KEY first. Never use a service_role key.')
flutter = 'flutter.bat' if sys.platform == 'win32' else 'flutter'
if not (root / 'android').exists():
    subprocess.run([sys.executable, str(root / 'scripts/bootstrap.py')], check=True)
subprocess.run([flutter, 'analyze', '--no-fatal-infos'], cwd=root, check=True)
subprocess.run([flutter, 'test'], cwd=root, check=True)
command = {'android':['apk','--release'], 'windows':['windows','--release'], 'ios':['ipa','--release']}[platform]
subprocess.run([flutter, 'build', *command, '--dart-define-from-file=config.json'], cwd=root, check=True)
