import copy
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


if __name__ == '__main__':
    unittest.main()
