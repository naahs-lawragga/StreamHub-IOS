#!/usr/bin/env python3
"""Generate an AltStore Classic source exclusively from published release assets.

The releases JSON must come from GitHub's releases API. No template version or
nonexistent artifact is ever inserted. URLs are checked over HTTPS before write.
"""
import argparse
import hashlib
import json
import datetime
import plistlib
import tempfile
import time
import zipfile
import urllib.error
import re
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

BUNDLE_ID = 'com.streamhub.ios'
VERSION = re.compile(r'^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$')


def https(url):
    value = urlparse(url)
    if value.scheme != 'https' or not value.hostname or value.username or value.password:
        raise ValueError('Expected an HTTPS URL without embedded credentials')
    return url


class HTTPSRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        https(newurl)
        return super().redirect_request(request, fp, code, message, headers, newurl)


OPENER = urllib.request.build_opener(HTTPSRedirectHandler())


def open_url(url):
    request = urllib.request.Request(https(url), headers={'User-Agent': 'StreamHub-Source-Generator/1'})
    for attempt in range(5):
        try:
            response = OPENER.open(request, timeout=60)
            https(response.url)
            return response
        except urllib.error.HTTPError as error:
            if error.code not in (404, 408, 429, 500, 502, 503, 504) or attempt == 4:
                raise
        except urllib.error.URLError:
            if attempt == 4:
                raise
        time.sleep(2 ** attempt)
    raise RuntimeError('Unreachable retry state')


def read_url(url):
    with open_url(url) as response:
        data = response.read(16385)
        if len(data) > 16384:
            raise ValueError('Checksum asset unexpectedly large')
        return data


def inspect_ipa(file, version):
    """Confirm source identity and version against the actual downloaded bundle."""
    file.seek(0)
    with zipfile.ZipFile(file) as archive:
        paths = [p for p in archive.infolist() if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist', p.filename)]
        if len(paths) != 1 or paths[0].file_size > 1024 * 1024:
            raise ValueError('IPA must contain exactly one main app Info.plist')
        info = plistlib.loads(archive.read(paths[0]))
    if info.get('CFBundleIdentifier') != BUNDLE_ID:
        raise ValueError('Public IPA has an unexpected bundle identifier')
    if info.get('CFBundleShortVersionString') != version:
        raise ValueError('Public IPA version does not match its release tag')
    if info.get('CFBundlePackageType') != 'APPL' or 'iPhoneOS' not in info.get('CFBundleSupportedPlatforms', []):
        raise ValueError('Public IPA is not a device application')
    minimum = info.get('MinimumOSVersion', '')
    if not isinstance(minimum, str) or not re.fullmatch(r'[0-9]+(?:\.[0-9]+){1,2}', minimum):
        raise ValueError('Public IPA has no valid minimum iOS version')
    build = info.get('CFBundleVersion', '')
    if not isinstance(build, str) or not re.fullmatch(r'[0-9]+(?:\.[0-9]+){0,2}', build):
        raise ValueError('Public IPA has no valid build version')
    return {'minOSVersion': minimum, 'buildVersion': build}


def verify_ipa(url, size, digest, version):
    if not isinstance(size, int) or isinstance(size, bool) or not 0 < size <= 1024 * 1024 * 1024:
        raise ValueError('Public IPA size is outside supported limits')
    with tempfile.TemporaryFile() as file:
        count, hasher = 0, hashlib.sha256()
        with open_url(url) as response:
            while block := response.read(1024 * 1024):
                count += len(block)
                if count > size:
                    raise ValueError('Public IPA exceeds declared size')
                hasher.update(block)
                file.write(block)
        if count != size or hasher.hexdigest() != digest:
            raise ValueError('Public IPA size or checksum does not match release')
        return inspect_ipa(file, version)


def validate_source(source):
    assert source['name'] and isinstance(source['apps'], list)
    for app in source['apps']:
        assert app['bundleIdentifier'] == BUNDLE_ID
        assert app['name'] and app['developerName'] and app['localizedDescription']
        https(app['iconURL'])
        assert app['appPermissions'] == {'entitlements': [], 'privacy': {}}
        assert app['versions'], 'Published app must have a release'
        seen = set()
        for version in app['versions']:
            assert VERSION.fullmatch(version['version'])
            assert version['version'] not in seen
            seen.add(version['version'])
            assert isinstance(version['size'], int) and version['size'] > 0
            assert re.fullmatch(r'[0-9]+(?:\.[0-9]+){0,2}', version['buildVersion'])
            assert re.fullmatch('[0-9a-f]{64}', version['sha256'])
            https(version['downloadURL'])
            https(version['streamhubReleaseURL'])


def generate(releases, repository, pages_url, verify=True):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Repository must be owner/name')
    pages_url = https(pages_url).rstrip('/')
    versions = []
    for release in releases:
        match = VERSION.fullmatch(release.get('tag_name', ''))
        if not match or release.get('draft') or release.get('prerelease'):
            continue
        assets = {asset['name']: asset for asset in release.get('assets', [])}
        ipa = assets.get('StreamHub-unsigned.ipa')
        checksum = assets.get('StreamHub-unsigned.ipa.sha256')
        if not ipa or not checksum:
            continue  # Other/older releases with no compatible artifacts stay absent.
        if ipa.get('state') != 'uploaded' or ipa.get('size', 0) <= 0:
            raise ValueError('IPA asset was not uploaded successfully')
        expected_prefix = f'https://github.com/{repository}/releases/download/{release["tag_name"]}/'
        for asset in (ipa, checksum):
            if https(asset['browser_download_url']) != expected_prefix + asset['name']:
                raise ValueError('Release asset is outside expected repository or tag')
        checksum_text = read_url(checksum['browser_download_url']).decode('ascii') if verify else checksum['test_checksum']
        parts = checksum_text.split()
        if not parts or not re.fullmatch('[0-9a-f]{64}', parts[0]):
            raise ValueError('Malformed SHA-256 checksum')
        digest = parts[0]
        version = '.'.join(match.groups())
        ipa_metadata = verify_ipa(ipa['browser_download_url'], ipa['size'], digest, version) if verify else {'minOSVersion': '17.0', 'buildVersion': '1'}
        date = release.get('published_at')
        if not isinstance(date, str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z', date):
            raise ValueError('Release has no valid publication date')
        datetime.datetime.strptime(date, '%Y-%m-%dT%H:%M:%SZ')
        versions.append({
            'version': '.'.join(match.groups()), 'date': date,
            'localizedDescription': release.get('body') or 'See the GitHub release for changes.',
            'downloadURL': ipa['browser_download_url'], 'size': ipa['size'],
            **ipa_metadata, 'sha256': digest,
            'streamhubReleaseURL': f'https://github.com/{repository}/releases/tag/{release["tag_name"]}'
        })
    if not versions:
        raise ValueError('No verified stable IPA exists; source publication refused')
    versions.sort(key=lambda item: tuple(map(int, item['version'].split('.'))), reverse=True)
    source = {
        'name': 'StreamHub', 'identifier': 'com.streamhub.source',
        'subtitle': 'Movie and television discovery',
        'description': 'Official StreamHub releases. Requires signing with a compatible installation tool.',
        'website': f'https://github.com/{repository}',
        'iconURL': pages_url + '/icon.png', 'tintColor': '#EF233C',
        'apps': [{
            'name': 'StreamHub', 'bundleIdentifier': BUNDLE_ID,
            'developerName': 'StreamHub contributors',
            'subtitle': 'Your next great watch starts here.',
            'localizedDescription': 'Discover movies and television, save a watchlist, browse supported websites, and play compatible authorized streams. Requires your own TMDB token for catalog data.',
            'iconURL': pages_url + '/icon.png', 'tintColor': '#EF233C',
            'category': 'entertainment',
            'screenshots': [pages_url + '/screenshots/setup.png'],
            'versions': versions,
            'appPermissions': {'entitlements': [], 'privacy': {}}
        }], 'news': []
    }
    validate_source(source)
    return source


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--releases', required=True)
    parser.add_argument('--repository', required=True)
    parser.add_argument('--pages-url', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    data = json.loads(Path(args.releases).read_text())
    # gh --paginate --slurp yields one array per response page.
    releases = [release for page in data for release in page] if data and isinstance(data[0], list) else data
    result = generate(releases, args.repository, args.pages_url)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(f'Validated source with {len(result["apps"][0]["versions"])} release(s): {output}')


if __name__ == '__main__':
    main()
