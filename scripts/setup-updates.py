#!/usr/bin/env python3
"""Configure Prelude's update key, optionally upload it to GitHub Actions."""
import argparse
import base64
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / ".build/artifacts/sparkle/Sparkle/bin"
ACCOUNT = "dev.yasin.prelude"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--github", action="store_true", help="Upload SPARKLE_PRIVATE_KEY using an authenticated GitHub CLI")
    args = parser.parse_args()
    if args.github and not shutil.which("gh"):
        parser.error("Install GitHub CLI and sign in first: brew install gh; gh auth login")
    if args.github:
        subprocess.run(["gh", "auth", "status"], check=True)
    if not (TOOLS / "generate_keys").is_file():
        subprocess.run(["swift", "package", "resolve"], cwd=ROOT, check=True)
    key_tool = str(TOOLS / "generate_keys")
    plist = ROOT / "Info.plist"
    existing = plistlib.loads(plist.read_bytes()).get("SUPublicEDKey", "")
    if not existing:
        subprocess.run([key_tool, "--account", ACCOUNT], check=True)
    public_key = subprocess.check_output([key_tool, "--account", ACCOUNT, "-p"], text=True).strip()
    if len(base64.b64decode(public_key, validate=True)) != 32:
        raise ValueError("Sparkle returned an invalid public key")
    if existing and existing != public_key:
        raise ValueError("The Keychain key differs from Info.plist. Restore the original key; do not replace a released update key.")
    subprocess.run(["/usr/libexec/PlistBuddy", "-c", f"Set :SUPublicEDKey {public_key}", str(plist)], check=True)
    print("Update public key configured in Info.plist. Private key remains in your login Keychain.")
    if args.github:
        old_mask = os.umask(0o077)
        try:
            with tempfile.TemporaryDirectory(prefix="prelude-update-key-") as folder:
                key_file = Path(folder) / "private-key"
                subprocess.run([key_tool, "--account", ACCOUNT, "-x", str(key_file)], check=True)
                with key_file.open("rb") as secret:
                    subprocess.run(["gh", "secret", "set", "SPARKLE_PRIVATE_KEY", "--repo", "csyasin/prelude"], stdin=secret, check=True)
        finally:
            os.umask(old_mask)
        print("SPARKLE_PRIVATE_KEY configured for csyasin/prelude. Temporary export removed.")
    else:
        print("To enable GitHub releases, sign in with GitHub CLI and run scripts/setup-updates.py --github once.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"Update setup failed: {error}")
