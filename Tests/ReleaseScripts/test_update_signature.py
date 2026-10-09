import base64
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform == "darwin", "Update verification uses macOS CryptoKit")
class UpdateSignatureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="prelude-signature-tests-")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.folder = Path(cls.temp.name)
        cls.verifier = cls.folder / "verify-update"
        subprocess.run(["xcrun", "swiftc", "-module-cache-path", str(cls.folder / "module-cache"),
                        str(ROOT / "scripts/verify-update.swift"), "-o", str(cls.verifier)], check=True, capture_output=True)
        cls.archive = cls.folder / "update.dmg"
        cls.archive.write_bytes(b"signed test artifact")
        # Disposable deterministic test seed; never use it to sign releases.
        seed = base64.b64encode(bytes(range(32))).decode()
        cls.public_key = "A6EHv/POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg="
        signer = ROOT / ".build/artifacts/sparkle/Sparkle/bin/sign_update"
        cls.signature = subprocess.check_output([str(signer), "--ed-key-file", "-", "-p", str(cls.archive)],
                                                input=seed, text=True).strip()

    def verify(self, archive=None, public_key=None, signature=None):
        return subprocess.run([str(self.verifier), public_key or self.public_key, str(archive or self.archive),
                               signature or self.signature], capture_output=True, text=True)

    def test_valid_signature_matches_embedded_public_key(self):
        result = self.verify()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_tampered_archive_is_rejected(self):
        tampered = self.folder / "tampered.dmg"
        tampered.write_bytes(self.archive.read_bytes() + b"tampered")
        self.assertNotEqual(self.verify(archive=tampered).returncode, 0)

    def test_wrong_public_key_is_rejected(self):
        self.assertNotEqual(self.verify(public_key=base64.b64encode(bytes(32)).decode()).returncode, 0)

    def test_forged_signature_is_rejected(self):
        self.assertNotEqual(self.verify(signature=base64.b64encode(bytes(64)).decode()).returncode, 0)


if __name__ == "__main__":
    unittest.main()
