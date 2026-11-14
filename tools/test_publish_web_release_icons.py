"""Regression: fonts remain readable to Nginx with a restrictive umask."""
import io
import json
import os
from pathlib import Path
import tarfile
import tempfile
import unittest

from publish_web_release import extract_bundle, sha


class IconAssetsTest(unittest.TestCase):
    def test_implicit_parent_directories_remain_world_executable(self):
        source = {
            'index.html': b'<html>ok</html>',
            'main.dart.js': b'window.testRelease = true;',
            'flutter_bootstrap.js': b'// boot',
            'firebase-messaging-sw.js': b'firebase.initializeApp({}); firebase.messaging();',
            'version.json': json.dumps({'version':'1.0.30','build_number':'99'}).encode(),
            'assets/FontManifest.json': json.dumps([{
                'family': 'MaterialIcons', 'fonts': [{'asset': 'fonts/MaterialIcons-Regular.otf'}]
            }]).encode(),
            'assets/fonts/MaterialIcons-Regular.otf': b'MOCK_MATERIAL_FONT',
            'assets/packages/cupertino_icons/assets/CupertinoIcons.ttf': b'MOCK_CUPERTINO_FONT',
        }
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp)/'bundle.tar.gz'
            with tarfile.open(archive,'w:gz') as tar:
                # No directory entries: this is what exposed the bug.
                for name,data in source.items():
                    info=tarfile.TarInfo(name)
                    info.size=len(data)
                    tar.addfile(info,io.BytesIO(data))
            target=Path(tmp)/'public'
            prior = os.umask(0o077)
            try:
                target.mkdir(mode=0o755)
                target.chmod(0o755)
                result=extract_bundle(archive,target,('1.0.30','99',
                    __import__('hashlib').sha256(source['main.dart.js']).hexdigest()))
            finally:
                os.umask(prior)
            self.assertEqual(str(result['build_number']), '99')
            for folder in (target/'assets',target/'assets/fonts',
                           target/'assets/packages/cupertino_icons/assets'):
                self.assertEqual(folder.stat().st_mode & 0o777,0o755,folder)
            for name,data in source.items():
                self.assertEqual((target/name).read_bytes(), data)


if __name__ == '__main__':
    unittest.main()
