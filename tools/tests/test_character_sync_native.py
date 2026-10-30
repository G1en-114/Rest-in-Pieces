"""Bounded loopback exchange using independent ENet APIs in one Godot engine."""
import os
from pathlib import Path
import socket
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT_BIN", "E:/Godot/Godot_v4.7.2-stable_win64_console.exe")


class CharacterSyncTest(unittest.TestCase):
    def test_models_sync_without_overwriting_local_choices(self):
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            for source in ("scripts/character_models.gd", "scripts/humanoid_rig.gd",
                           "scripts/character_sync.gd", "tests/test_character_sync.gd",
                           "tests/fixtures/humanoid_glb.gd"):
                destination = project / source
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / "game" / source, destination)
            (project / "project.godot").write_text(
                'config_version=5\n[application]\nconfig/name="sync-fixture"\n', encoding="utf-8")
            run = subprocess.run(
                [GODOT, "--headless", "--path", str(project), "--script",
                 "res://tests/test_character_sync.gd", "--", f"--port={port}"],
                capture_output=True, timeout=25)
            output = (run.stdout + run.stderr).decode("utf-8", errors="replace")
            self.assertEqual(run.returncode, 0, output)
            self.assertNotIn("ERROR:", output, output)
            self.assertIn("SYNC_FIXTURE_PASS", output, output)


if __name__ == "__main__":
    unittest.main()
