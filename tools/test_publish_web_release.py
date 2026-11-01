import io
from pathlib import Path
import tarfile
import tempfile
import unittest
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

if __name__=='__main__':unittest.main()
