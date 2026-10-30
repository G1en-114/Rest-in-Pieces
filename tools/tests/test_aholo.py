"""Lux3D CLI regression tests; use a local HTTP server, never the paid API."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "aholo.py"


class AholoCLITest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "tools").mkdir()
        shutil.copyfile(SCRIPT, self.root / "tools/aholo.py")
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("AHOLO_")}
        self.env["PYTHONIOENCODING"] = "utf-8"

    def run_cli(self, *args):
        return subprocess.run(
            [sys.executable, str(self.root / "tools/aholo.py"), *args],
            cwd=self.root, env=self.env, capture_output=True,
            encoding="utf-8", timeout=5,
        )

    def serve(self, task=None, key="test-key"):
        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                valid = (self.path == "/lux3d/v1/generate/text-to-3d/task/create"
                         and self.headers.get("Authorization") == key
                         and body == {"prompt": "test character", "style": "cartoon",
                                      "version": "G1", "faceCount": 20000})
                self.reply({"c": "0", "d": "local-task"} if valid else {"c": "1"})

            def do_GET(self):
                if self.path == "/model.glb":
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"local-model-fixture")
                elif self.path == "/lux3d/v1/generate/task/get?taskid=local-task":
                    self.reply({"c": "0", "d": task})
                else:
                    self.send_error(404)

            def reply(self, value):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps(value).encode())

            def log_message(self, *_args):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        base = f"http://127.0.0.1:{server.server_port}"
        self.env.update(AHOLO_API_KEY=key, AHOLO_BASE_URL=base)
        return base

    def test_help_works_without_dotenv(self):
        result = self.run_cli("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("text3d", result.stdout)

    def test_missing_key_reports_configuration_error(self):
        result = self.run_cli("text3d", "test character")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("AHOLO_API_KEY", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_environment_credentials_work_without_dotenv(self):
        self.serve()
        result = self.run_cli("text3d", "test character")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("local-task", result.stdout)

    def test_environment_overrides_dotenv(self):
        self.serve(key="environment-key")
        (self.root / ".env").write_text(
            "AHOLO_API_KEY=file-key\nAHOLO_BASE_URL=http://127.0.0.1:1\n",
            encoding="utf-8",
        )
        result = self.run_cli("text3d", "test character")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_quoted_dotenv_credentials_work(self):
        base = self.serve()
        self.env.pop("AHOLO_API_KEY")
        self.env.pop("AHOLO_BASE_URL")
        (self.root / ".env").write_text(
            f'AHOLO_API_KEY="test-key"\nAHOLO_BASE_URL=\'{base}\'\n', encoding="utf-8",
        )
        result = self.run_cli("text3d", "test character")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_pending_task_stops_at_timeout(self):
        self.serve(task={"status": 1, "outputs": []})
        result = self.run_cli("wait", "local-task", "--timeout", "0.1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("超时", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_invalid_timeout_is_rejected_before_request(self):
        for value in ("0", "-1", "nan", "inf"):
            with self.subTest(value=value):
                result = self.run_cli("wait", "local-task", "--timeout", value)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("--timeout", result.stderr)

    def test_success_saves_metadata_and_downloads_model(self):
        task = {"status": 3, "outputs": []}
        base = self.serve(task=task)
        task["outputs"].append({"content": base + "/model.glb"})
        result = self.run_cli("wait", "local-task")
        self.assertEqual(result.returncode, 0, result.stderr)
        out = self.root / "generated/local-task"
        self.assertEqual(json.loads((out / "task.json").read_text(encoding="utf-8")), task)
        self.assertEqual((out / "0_model.glb").read_bytes(), b"local-model-fixture")

    def test_failed_task_preserves_metadata_and_exits_nonzero(self):
        task = {"status": 4, "outputs": []}
        self.serve(task=task)
        result = self.run_cli("wait", "local-task")
        self.assertNotEqual(result.returncode, 0)
        out = self.root / "generated/local-task/task.json"
        self.assertEqual(json.loads(out.read_text(encoding="utf-8")), task)


if __name__ == "__main__":
    unittest.main()
