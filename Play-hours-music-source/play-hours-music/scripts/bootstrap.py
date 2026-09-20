"""Generate standard native Flutter runners and apply app branding. Run once per checkout."""
from pathlib import Path
import subprocess
import re
import sys

root = Path(__file__).resolve().parents[1]
flutter = 'flutter.bat' if sys.platform == 'win32' else 'flutter'
subprocess.run([flutter, 'create', '--platforms=android,ios,windows', '--org=com.playhours',
                '--project-name=play_hours_music', '--no-pub', '.'], cwd=root, check=True)
# flutter create may add the default counter test; it is unrelated to this app.
default_test = root / 'test/widget_test.dart'
if default_test.exists() and 'counter' in default_test.read_text().lower():
    default_test.unlink()
manifest = root / 'android/app/src/main/AndroidManifest.xml'
s = manifest.read_text()
s = s.replace('android:label="play_hours_music"', 'android:label="Play-hours music"')
if 'android.permission.INTERNET' not in s:
    s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
manifest.write_text(s)
plist = root / 'ios/Runner/Info.plist'
s = plist.read_text()
s = re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>).*?(</string>)', r'\g<1>Play-hours music\2', s)
s = re.sub(r'(<key>CFBundleName</key>\s*<string>).*?(</string>)', r'\g<1>Play-hours music\2', s)
plist.write_text(s)
runner = root / 'windows/runner/main.cpp'
s = runner.read_text().replace('L"play_hours_music"', 'L"Play-hours music"')
runner.write_text(s)
rc = root / 'windows/runner/Runner.rc'
s = rc.read_text().replace('"play_hours_music"', '"Play-hours music"')
rc.write_text(s)
subprocess.run([flutter, 'pub', 'get'], cwd=root, check=True)
subprocess.run(['dart.bat' if sys.platform == 'win32' else 'dart', 'run', 'flutter_launcher_icons'], cwd=root, check=True)
print('Native runners and icons are ready.')
