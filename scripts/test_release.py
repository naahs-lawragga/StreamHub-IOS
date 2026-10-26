import io
import hashlib
import plistlib
import zipfile
from unittest.mock import patch
import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('source', Path(__file__).with_name('generate-source.py'))
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)


class SourceTests(unittest.TestCase):
    def release(self, tag='v0.1.0'):
        base = f'https://github.com/example/StreamHub-iOS/releases/download/{tag}/'
        return {'tag_name': tag, 'published_at': '2026-10-26T00:00:00Z', 'body': 'Initial release',
                'assets': [{'name': 'StreamHub-unsigned.ipa', 'browser_download_url': base + 'StreamHub-unsigned.ipa', 'size': 1234, 'state': 'uploaded'},
                           {'name': 'StreamHub-unsigned.ipa.sha256', 'browser_download_url': base + 'StreamHub-unsigned.ipa.sha256', 'test_checksum': 'a' * 64}]}

    def generate(self, releases):
        return source.generate(releases, 'example/StreamHub-iOS', 'https://example.github.io/StreamHub-iOS', verify=False)

    def test_empty_and_missing_assets_never_published(self):
        for releases in ([], [{'tag_name': 'v1.0.0', 'assets': []}]):
            with self.assertRaises(ValueError):
                self.generate(releases)

    def test_versions_sorted_semantically(self):
        data = self.generate([self.release('v1.2.0'), self.release('v1.10.0')])
        self.assertEqual([v['version'] for v in data['apps'][0]['versions']], ['1.10.0', '1.2.0'])
        self.assertTrue(all(v['buildVersion'] == '1' for v in data['apps'][0]['versions']))

    def test_draft_and_prerelease_excluded(self):
        for flag in ('draft', 'prerelease'):
            value = self.release()
            value[flag] = True
            with self.assertRaises(ValueError):
                self.generate([value])

    def test_wrong_host_rejected(self):
        value = self.release()
        value['assets'][0]['browser_download_url'] = 'https://evil.example/StreamHub-unsigned.ipa'
        with self.assertRaises(ValueError):
            self.generate([value])

    def test_bad_checksum_and_size_rejected(self):
        for mutation in ('checksum', 'size'):
            value = self.release()
            if mutation == 'checksum':
                value['assets'][1]['test_checksum'] = 'not-a-checksum'
            else:
                value['assets'][0]['size'] = 0
            with self.assertRaises(ValueError):
                self.generate([value])

    def test_insecure_or_credential_url_rejected(self):
        for url in ('http://example.com', 'https://user:secret@example.com', 'file:///tmp/a'):
            with self.assertRaises(ValueError):
                source.https(url)

    def test_empty_checksum_and_impossible_date_rejected(self):
        value = self.release()
        value['assets'][1]['test_checksum'] = ''
        with self.assertRaises(ValueError):
            self.generate([value])
        value = self.release()
        value['published_at'] = '2026-99-99T00:00:00Z'
        with self.assertRaises(ValueError):
            self.generate([value])

    def test_asset_for_different_tag_rejected(self):
        value = self.release()
        value['assets'][0]['browser_download_url'] = value['assets'][0]['browser_download_url'].replace('v0.1.0', 'v9.0.0')
        with self.assertRaises(ValueError):
            self.generate([value])

    def ipa(self, **overrides):
        info = {'CFBundleIdentifier': source.BUNDLE_ID,
                'CFBundleShortVersionString': '0.1.1',
                'CFBundleVersion': '17',
                'CFBundlePackageType': 'APPL',
                'CFBundleSupportedPlatforms': ['iPhoneOS'],
                'MinimumOSVersion': '17.0'}
        info.update(overrides)
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w') as archive:
            archive.writestr('Payload/StreamHub.app/Info.plist', plistlib.dumps(info))
        return buffer.getvalue()

    def test_ipa_identity_version_and_platform(self):
        self.assertEqual(source.inspect_ipa(io.BytesIO(self.ipa()), '0.1.1'), {'minOSVersion': '17.0', 'buildVersion': '17'})
        for overrides in ({'CFBundleIdentifier': 'other.app'},
                          {'CFBundleShortVersionString': '0.1.0'},
                          {'CFBundleSupportedPlatforms': ['iPhoneSimulator']},
                          {'MinimumOSVersion': 'unknown'},
                          {'CFBundleVersion': ''},
                          {'CFBundleVersion': 'not-a-build'}):
            with self.assertRaises(ValueError):
                source.inspect_ipa(io.BytesIO(self.ipa(**overrides)), '0.1.1')

    def test_download_integrity_checked_before_source_entry(self):
        data = self.ipa()
        digest = hashlib.sha256(data).hexdigest()
        with patch.object(source, 'open_url', return_value=io.BytesIO(data)):
            self.assertEqual(source.verify_ipa('https://example.com/app.ipa', len(data), digest, '0.1.1'), {'minOSVersion': '17.0', 'buildVersion': '17'})
        for size, checksum in ((len(data) - 1, digest), (len(data) + 1, digest), (len(data), '0' * 64)):
            with patch.object(source, 'open_url', return_value=io.BytesIO(data)):
                with self.assertRaises(ValueError):
                    source.verify_ipa('https://example.com/app.ipa', size, checksum, '0.1.1')

    def test_https_redirect_cannot_downgrade(self):
        with self.assertRaises(ValueError):
            source.HTTPSRedirectHandler().redirect_request(None, None, 302, '', {}, 'http://example.com/ipa')


if __name__ == '__main__':
    unittest.main()
