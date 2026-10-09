import hashlib
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[2]


class ReleaseScriptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="prelude-release-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.origin = self.root / "origin.git"
        self.repo.mkdir()
        (self.repo / "scripts").mkdir()
        shutil.copy2(PROJECT_DIR / "scripts/release.py", self.repo / "scripts/release.py")
        (self.repo / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1"
        }))
        self.env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        self.env.update({
            "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "Release Test", "GIT_AUTHOR_EMAIL": "test@example.invalid",
            "GIT_COMMITTER_NAME": "Release Test", "GIT_COMMITTER_EMAIL": "test@example.invalid",
        })
        self.command("git", "init", "--bare", "--quiet", str(self.origin))
        self.git("init", "--quiet", "-b", "main")
        self.git("remote", "add", "origin", str(self.origin))
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "test: release fixture")

    def command(self, *arguments, cwd=None, check=True):
        result = subprocess.run(arguments, cwd=cwd or self.repo, env=self.env, text=True, capture_output=True)
        if check:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def git(self, *arguments, check=True):
        return self.command("git", *arguments, check=check)

    def release(self, *arguments, check=True):
        return self.command(sys.executable, "-B", "scripts/release.py", *arguments, check=check)

    def version(self):
        return plistlib.loads((self.repo / "Info.plist").read_bytes())["CFBundleShortVersionString"]

    def remote_ref(self, name):
        return self.command("git", "--git-dir", str(self.origin), "rev-parse", name).stdout.strip()

    def test_first_release_preserves_requested_version(self):
        head = self.git("rev-parse", "HEAD").stdout.strip()
        self.release("current")
        self.assertEqual(self.version(), "0.1.0")
        self.assertEqual(self.remote_ref("refs/tags/v0.1.0^{commit}"), head)
        self.assertEqual(self.remote_ref("refs/heads/main"), head)

    def test_only_requested_tag_is_pushed_with_follow_tags_configured(self):
        self.git("config", "push.followTags", "true")
        self.git("tag", "-a", "unrelated-tag", "-m", "Unrelated tag")
        self.release("current")
        result = self.command("git", "--git-dir", str(self.origin), "show-ref", "--verify", "refs/tags/unrelated-tag", check=False)
        self.assertNotEqual(result.returncode, 0)

    def test_increment_updates_source_commit_and_remote_tag(self):
        self.release("current")
        for selection, expected in [("patch", "0.1.1"), ("minor", "0.2.0"), ("major", "1.0.0"), ("1.2.3", "1.2.3")]:
            with self.subTest(selection=selection):
                self.release(selection)
                self.assertEqual(self.version(), expected)
                self.assertEqual(self.git("log", "-1", "--format=%s").stdout.strip(), f"chore: release v{expected}")
                self.assertEqual(self.remote_ref(f"refs/tags/v{expected}^{{commit}}"), self.remote_ref("refs/heads/main"))
                self.assertEqual(self.git("status", "--porcelain").stdout, "")

    def test_dry_run_has_no_file_git_or_network_side_effects(self):
        self.git("remote", "set-url", "origin", str(self.root / "nonexistent-origin"))
        (self.repo / "uncommitted.txt").write_text("keep this change")
        before = (self.repo / "Info.plist").read_bytes()
        head = self.git("rev-parse", "HEAD").stdout
        self.release("patch", "--dry-run")
        self.assertEqual((self.repo / "Info.plist").read_bytes(), before)
        self.assertEqual(self.git("rev-parse", "HEAD").stdout, head)
        self.assertEqual(self.git("tag", "--list").stdout, "")

    def test_uncommitted_changes_are_not_staged_or_released(self):
        (self.repo / "application.txt").write_text("uncommitted")
        result = self.release("patch", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("working tree must be clean", result.stderr)
        self.assertEqual(self.version(), "0.1.0")
        self.assertEqual(self.git("diff", "--cached", "--name-only").stdout, "")
        self.assertEqual(self.git("tag", "--list").stdout, "")

    def test_published_version_and_invalid_versions_are_rejected(self):
        self.release("current")
        for selection in ["current", "0.0.9", "01.2.3", "0.1.1-beta.1", "0.1.1;echo unsafe"]:
            with self.subTest(selection=selection):
                self.assertNotEqual(self.release(selection, check=False).returncode, 0)
                self.assertEqual(self.version(), "0.1.0")

    def test_behind_remote_branch_is_rejected_before_version_change(self):
        self.release("current")
        peer = self.root / "peer"
        self.command("git", "clone", "--quiet", "--branch", "main", str(self.origin), str(peer))
        (peer / "change.txt").write_text("remote change")
        self.command("git", "add", ".", cwd=peer)
        self.command("git", "commit", "--quiet", "-m", "fix: remote change", cwd=peer)
        self.command("git", "push", "--quiet", "origin", "main", cwd=peer)
        result = self.release("patch", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("behind or diverged", result.stderr)
        self.assertEqual(self.version(), "0.1.0")

    def test_failed_atomic_push_can_resume_without_another_bump(self):
        self.release("current")
        hook = self.origin / "hooks/pre-receive"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        old_remote_head = self.remote_ref("refs/heads/main")
        result = self.release("patch", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("release.py current", result.stderr)
        self.assertEqual(self.version(), "0.1.1")
        self.assertEqual(self.remote_ref("refs/heads/main"), old_remote_head)
        self.assertNotEqual(self.command("git", "--git-dir", str(self.origin), "show-ref", "--verify", "refs/tags/v0.1.1", check=False).returncode, 0)
        hook.unlink()
        release_commit = self.git("rev-parse", "HEAD").stdout.strip()
        self.release("current")
        self.assertEqual(self.git("rev-parse", "HEAD").stdout.strip(), release_commit)
        self.assertEqual(self.remote_ref("refs/tags/v0.1.1^{commit}"), release_commit)

    def test_failed_version_commit_restores_version_file_and_index(self):
        hook = self.repo / ".git/hooks/pre-commit"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        self.assertNotEqual(self.release("patch", check=False).returncode, 0)
        self.assertEqual(self.version(), "0.1.0")
        self.assertEqual(self.git("status", "--porcelain").stdout, "")
        self.assertEqual(self.git("tag", "--list").stdout, "")


class PublishScriptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="prelude-publish-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        (self.root / "dist").mkdir()
        (self.root / "bin").mkdir()
        shutil.copy2(PROJECT_DIR / "scripts/publish-release.sh", self.root / "scripts/publish-release.sh")
        payload = b"test release artifact"
        (self.root / "dist/Prelude.dmg").write_bytes(payload)
        (self.root / "dist/Prelude.dmg.sha256").write_text(f"{hashlib.sha256(payload).hexdigest()}  Prelude.dmg\n")
        (self.root / "dist/appcast.xml").write_text("<rss><channel/></rss>\n")
        self.log = self.root / "gh-calls.jsonl"
        fake_gh = self.root / "bin/gh"
        fake_gh.write_text("""#!/usr/bin/env python3
import json, os, sys
with open(os.environ['FAKE_GH_LOG'], 'a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\\n')
action = sys.argv[2]
if action == 'view':
    state = os.environ['FAKE_RELEASE_STATE']
    if state == 'missing':
        sys.exit(1)
    print(state)
if action == 'upload' and os.environ.get('FAKE_UPLOAD_FAILURE') == '1':
    sys.exit(1)
""")
        fake_gh.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{self.root / 'bin'}:{os.environ['PATH']}",
                        FAKE_GH_LOG=str(self.log), GITHUB_REPOSITORY="test/release-fixture")

    def publish(self, state, upload_failure=False):
        env = dict(self.env, FAKE_RELEASE_STATE=state, FAKE_UPLOAD_FAILURE="1" if upload_failure else "0")
        result = subprocess.run(["bash", "scripts/publish-release.sh", "v0.1.0"], cwd=self.root,
                                env=env, text=True, capture_output=True)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return result, calls

    def test_new_release_attaches_artifacts_and_update_feed(self):
        result, calls = self.publish("missing")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call[1] for call in calls], ["view", "create"])
        self.assertIn("dist/Prelude.dmg", calls[-1])
        self.assertIn("dist/Prelude.dmg.sha256", calls[-1])
        self.assertIn("dist/appcast.xml", calls[-1])
        self.assertIn("--verify-tag", calls[-1])

    def test_draft_retry_uploads_before_publishing(self):
        result, calls = self.publish("true")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call[1] for call in calls], ["view", "upload", "edit"])
        self.assertIn("--draft=false", calls[-1])
        self.assertIn("dist/appcast.xml", calls[-2])

    def test_published_release_is_never_overwritten(self):
        result, calls = self.publish("false")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([call[1] for call in calls], ["view"])

    def test_failed_upload_does_not_publish_draft(self):
        result, calls = self.publish("true", upload_failure=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([call[1] for call in calls], ["view", "upload"])

    def test_missing_update_feed_prevents_publication(self):
        (self.root / "dist/appcast.xml").unlink()
        result, calls = self.publish("missing")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_corrupted_archive_prevents_publication(self):
        (self.root / "dist/Prelude.dmg").write_bytes(b"corrupted")
        result, calls = self.publish("missing")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
