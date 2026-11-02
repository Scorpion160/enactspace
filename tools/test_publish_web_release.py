from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import publish_web_release as publish

class Tests(unittest.TestCase):
    def unsafe_archive(self,name,kind):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);archive=root/'test.tar.gz';target=root/'target';target.mkdir()
            with tarfile.open(archive,'w:gz') as tar:
                info=tarfile.TarInfo(name);info.type=kind
                if kind==tarfile.REGTYPE:
                    info.size=1;tar.addfile(info,io.BytesIO(b'x'))
                else:
                    info.linkname='/outside';tar.addfile(info)
            with self.assertRaisesRegex(RuntimeError,'Unsafe_archive_member'):
                publish.extract_bundle(archive,target)
            self.assertEqual(list(target.iterdir()),[])
    def test_parent_traversal_rejected(self):self.unsafe_archive('../outside',tarfile.REGTYPE)
    def test_absolute_path_rejected(self):self.unsafe_archive('/outside',tarfile.REGTYPE)
    def test_symlink_rejected(self):self.unsafe_archive('link',tarfile.SYMTYPE)
    def test_hardlink_rejected(self):self.unsafe_archive('link',tarfile.LNKTYPE)
    def test_duplicate_file_rejected_before_extraction(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);archive=root/'test.tar.gz';target=root/'target';target.mkdir()
            with tarfile.open(archive,'w:gz') as tar:
                for _ in range(2):
                    info=tarfile.TarInfo('index.html');info.size=1;tar.addfile(info,io.BytesIO(b'x'))
            with self.assertRaisesRegex(RuntimeError,'Duplicate'):publish.extract_bundle(archive,target)
            self.assertEqual(list(target.iterdir()),[])

    def test_custom_release_with_production_version_guard(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            live = root / 'web'
            live.mkdir()
            (live / 'main.dart.js').write_text('old javascript')
            (live / 'version.json').write_text('{"version":"1.0.23","build_number":"26"}')
            baseline = ['1.0.23', '26', publish.sha(live / 'main.dart.js')]

            source = root / 'source'
            source.mkdir()
            for name in publish.REQUIRED:
                (source / name).write_text(name)
            (source / 'version.json').write_text('{"version":"1.0.24","build_number":27}')
            (source / 'firebase-messaging-sw.js').write_text('firebase.initializeApp();firebase.messaging();')
            release = ['1.0.24', '27', publish.sha(source / 'main.dart.js')]
            archive = root / 'web-release.tar.gz'
            with tarfile.open(archive, 'w:gz') as tar:
                tar.add(source, arcname='.')

            def scoped_path(value):
                path = Path(value)
                if path.is_relative_to('/opt/enactspace'):
                    return root / path.relative_to('/opt/enactspace')
                return path

            container = {
                'Mounts': [{'Destination': '/usr/share/nginx/html', 'Type': 'bind', 'Source': str(live)}],
                'Config': {'Labels': {
                    'com.docker.compose.project': 'enactspace',
                    'com.docker.compose.service': 'web',
                    'com.docker.compose.project.config_files': '/opt/enactspace/app/deploy/docker-compose.vps.yml',
                }},
            }
            args = ['--archive', str(archive), '--archive-sha256', publish.sha(archive),
                    '--release', *release, '--expected-live', *baseline, '--execute']
            with patch.object(publish, 'Path', scoped_path), \
                 patch.object(publish, 'run', return_value=json.dumps([container])) as docker, \
                 patch.object(publish, 'check_live', return_value=list(publish.REQUIRED)):
                out = io.StringIO()
                wrong_baseline = [*args[:-2], '0' * 64, '--execute']
                with redirect_stdout(out):
                    self.assertEqual(publish.main(wrong_baseline), 1)
                self.assertEqual(json.loads(out.getvalue())['reason'], 'Unexpected_live_release')
                self.assertEqual(docker.call_count, 1)
                publish.check_release(live, baseline)

                out = io.StringIO()
                with redirect_stdout(out):
                    self.assertEqual(publish.main(args), 0)
                report = json.loads(out.getvalue())
                self.assertEqual(report['status'], 'WEB_DEPLOYED_LOCAL_CHECKS_PASSED')
                publish.check_release(live, release)
                publish.check_release(Path(report['rollback_directory']), baseline)

if __name__=='__main__':unittest.main()
