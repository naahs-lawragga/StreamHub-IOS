#!/usr/bin/env python3
"""Validate the built device bundle and produce a side-signing IPA."""
import os, plistlib, stat, sys, zipfile
from pathlib import Path
app, output = map(Path, sys.argv[1:])
with (app / 'Info.plist').open('rb') as f:
    info = plistlib.load(f)
assert info['CFBundleIdentifier'] == 'com.streamhub.ios', 'Unexpected bundle identity'
assert info['CFBundlePackageType'] == 'APPL'
assert 'iPhoneOS' in info.get('CFBundleSupportedPlatforms', []), 'Simulator bundles cannot be installed'
assert tuple(map(int, info['MinimumOSVersion'].split('.'))) >= (17, 0)
executable = app / info['CFBundleExecutable']
assert executable.is_file() and executable.stat().st_size > 0
assert (app / 'Assets.car').is_file(), 'Compiled assets missing'
assert not (app / 'PlugIns').exists(), 'Unexpected app extensions'
output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(app.rglob('*')):
        if file.is_file():
            archive.write(file, str(Path('Payload') / app.name / file.relative_to(app)))
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    assert f'Payload/{app.name}/Info.plist' in archive.namelist()
print(f'Validated unsigned device IPA: {output} ({output.stat().st_size} bytes)')
