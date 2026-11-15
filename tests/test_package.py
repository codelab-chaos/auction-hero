import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("package", ROOT / "scripts/package.py")
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class PackagingTests(unittest.TestCase):
    def test_installable_archive_and_checksum(self):
        original = (ROOT / "AuctionHero/AuctionHero.toc").read_bytes()
        with tempfile.TemporaryDirectory() as output:
            archive = package.build("v0.2.0-alpha.1", output)
            with zipfile.ZipFile(archive) as release:
                self.assertIsNone(release.testzip())
                names = release.namelist()
                self.assertTrue(all(name.startswith("AuctionHero/") for name in names))
                toc = release.read("AuctionHero/AuctionHero.toc").decode()
                self.assertIn("## Version: 0.2.0-alpha.1\n", toc)
                self.assertEqual(release.read("AuctionHero/LICENSE"), (ROOT / "LICENSE").read_bytes())
                for line in package.toc_files(toc):
                    self.assertIn("AuctionHero/" + line, names)
                self.assertFalse(any("tests/" in name or ".deploy-target" in name for name in names))
            checksum, filename = archive.with_suffix(".zip.sha256").read_text().split()
            self.assertEqual(checksum, hashlib.sha256(archive.read_bytes()).hexdigest())
            self.assertEqual(filename, archive.name)
        self.assertEqual((ROOT / "AuctionHero/AuctionHero.toc").read_bytes(), original)

    def test_versions(self):
        for value in ("0.1.0", "v1.2.3", "2.0.0-alpha.1", "1.0.0-rc.2"):
            with self.subTest(value=value):
                self.assertEqual(package.normalize_version(value), value.removeprefix("v"))
        for value in ("latest", "1.0", "01.0.0", "v1.0.0-01", "1.0.0/../../file", "1.0.0\ninvalid"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                package.normalize_version(value)


if __name__ == "__main__":
    unittest.main()
