"""Native Godot API integration checks; all HTTP traffic stays on loopback."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path(os.environ.get("GODOT_BIN", "E:/Godot/Godot_v4.7.2-stable_win64_console.exe"))
CLIENT = ROOT / "game/scripts/lux3d_client.gd"
MODEL = b"glTF" + struct.pack("<II", 2, 12)


class NativeLux3DTest(unittest.TestCase):
    def run_client(self, mode="success", *, resume="", stage="generate", region="cn", key="fixture-key"):
        self.assertTrue(CLIENT.is_file(), "Native Lux3D client has not been implemented")
        requests = []
        errors = []
        polls = {}
        prefix = "/global" if region == "com" else ""

        class Handler(BaseHTTPRequestHandler):
            def reply(self, value, status=200):
                raw = json.dumps(value).encode()
                self.send_response(status)
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

            def do_POST(self):
                try:
                    data = self.rfile.read(int(self.headers.get("Content-Length", "0")))
                    requests.append(("POST", self.path))
                    if self.path == "/ous/api/v2/single/upload":
                        assert self.headers.get("ous-token-v2") == "upload-secret"
                        assert self.headers.get("Authorization") is None
                        boundary = self.headers["Content-Type"].split("boundary=")[1].encode()
                        parts = data.split(b"--" + boundary)
                        digest = next(p.split(b"\r\n\r\n", 1)[1][:-2] for p in parts if b'name="md5"' in p)
                        image = next(p.split(b"\r\n\r\n", 1)[1][:-2] for p in parts if b'name="file"' in p)
                        assert hashlib.md5(image).hexdigest().encode() == digest
                        assert image[:3] == b"\xff\xd8\xff" or image[:8] == b"\x89PNG\r\n\x1a\n"
                        self.reply({} if mode == "malformed_upload" else {"c": "0"})
                    else:
                        assert self.headers.get("Authorization") == key
                        body = json.loads(data)
                        if self.path == prefix + "/lux3d/v1/generate/img-to-3d/task/create":
                            assert body == {"img": base + "/photo.jpg", "version": "G1", "faceCount": 20000, "outputFormat": ["glb"]}
                            if mode in ("uncertain_create", "cancel_create"):
                                time.sleep(1.2)
                                self.close_connection = True
                                return
                            self.reply({"c": "0", "d": "100"})
                        elif self.path == prefix + "/lux3d/v1/animations/rig/task/create":
                            assert body == {"modelUrl": base + "/generated.glb"}
                            if mode == "uncertain_rig":
                                time.sleep(1.2)
                                self.close_connection = True
                                return
                            self.reply({"c": "0", "d": "200"})
                        else:
                            raise AssertionError("unexpected POST " + self.path)
                except Exception as exc:
                    errors.append(str(exc))
                    self.reply({"c": "1"})

            def do_GET(self):
                requests.append(("GET", self.path))
                if self.path == "/rigged.glb":
                    assert self.headers.get("Authorization") is None
                    self.send_response(200)
                    self.send_header("Content-Length", str(33 * 1024 * 1024 if mode == "oversize" else len(MODEL)))
                    self.end_headers()
                    self.wfile.write(MODEL)
                    return
                if self.path.startswith("/ous/"):
                    if self.headers.get("ous-token-v2") != "upload-secret":
                        errors.append("missing OUS token")
                    self.reply({"c": "0", "d": {"status": 5, "url": base + "/photo.jpg"}})
                    return
                if self.headers.get("Authorization") != key:
                    errors.append("incorrect raw gateway key")
                if self.path == prefix + "/asset/v1/token":
                    if mode == "gateway_failure":
                        self.reply({"message": key, "status": "UNAUTHENTICATED"}, 401)
                    else:
                        self.reply({"globalDomain": base, "ousToken": "upload-secret", "blockSize": {} if mode == "malformed_token" else 1024 * 1024})
                elif self.path.startswith(prefix + "/lux3d/v1/generate/task/get?"):
                    task = parse_qs(urlsplit(self.path).query)["taskid"][0]
                    polls[task] = polls.get(task, 0) + 1
                    status = 4 if mode == "failed" else 6 if mode == "remote_cancel" else 1 if mode in ("cancel", "timeout") or polls[task] == 1 else 3
                    if mode == "malformed_status":
                        status = {}
                    path = "/generated.glb" if task == "100" else "/rigged.glb"
                    content = base + path
                    if mode == "not_riggable" and task != "100":
                        # Shape of a real rejected rig task (2026-10-27): status 4, reason JSON in content.
                        status = 4
                        content = json.dumps({"error": {"code": "MODEL_NOT_RIGGABLE", "message": "双臂弯曲持握吉他，不符合可绑骨的基础T-Pose或A-Pose要求。"}}, ensure_ascii=False)
                    self.reply({"c": "0", "d": {"taskId": task, "status": status, "outputs": [{"content": content}]}})
                else:
                    errors.append("unexpected GET " + self.path)
                    self.reply({"c": "1"})

            def log_message(self, *_args):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f"http://127.0.0.1:{server.server_port}"
        try:
            with tempfile.TemporaryDirectory() as temp:
                project = Path(temp)
                shutil.copyfile(CLIENT, project / "client.gd")
                (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="fixture"\n', encoding="utf-8")
                script = '''extends SceneTree
var tasks: Array = []
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var client = load("res://client.gd").new()
    root.add_child(client)
    client.gateway_base = %s
    client.poll_interval_seconds = 0.02
    client.poll_timeout_seconds = 0.15
    client.request_timeout_seconds = 1.0
    client.task_created.connect(func(id, stage): tasks.append([id, stage]))
    var image = Image.create(16, 16, false, Image.FORMAT_RGB8)
    image.fill(Color.RED)
    var path = "user://photo.png"
    image.save_png(path)
    if %s == "invalid_image":
        var file = FileAccess.open(path, FileAccess.WRITE)
        file.store_string("not an image")
        file.close()
    if %s in ["cancel", "cancel_create"]:
        get_tree_cancel(client)
    var result = await client.generate(path, %s, %s, %s, %s)
    if result.get("ok", false):
        result["size"] = result["data"].size()
        result.erase("data")
    result["tasks"] = tasks
    print("FIXTURE_RESULT=" + JSON.stringify(result))
    quit(0)
func get_tree_cancel(client) -> void:
    await create_timer(0.2 if %s == "cancel_create" else 0.08).timeout
    client.cancel()
''' % tuple(json.dumps(x) for x in (base, mode, mode, key, region, resume, stage, mode))
                (project / "run.gd").write_text(script, encoding="utf-8")
                run = subprocess.run([str(GODOT), "--headless", "--path", temp, "--script", "run.gd"], capture_output=True, encoding="utf-8", timeout=12)
                self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
                self.assertNotIn("SCRIPT ERROR", run.stderr, run.stderr)
                line = next((line for line in run.stdout.splitlines() if line.startswith("FIXTURE_RESULT=")), None)
                self.assertIsNotNone(line, run.stdout + run.stderr)
                self.assertEqual(errors, [])
                return json.loads(line.split("=", 1)[1]), requests
        finally:
            server.shutdown()
            server.server_close()

    def test_upload_generate_rig_download(self):
        result, requests = self.run_client()
        self.assertTrue(result["ok"], result)
        self.assertEqual(result["size"], len(MODEL))
        self.assertEqual(result["tasks"], [["", "generate_pending"], ["100", "generate"], ["100", "rig_pending"], ["200", "rig"]])
        self.assertEqual(sum(method == "POST" for method, _ in requests), 3)

    def test_international_prefix(self):
        result, _ = self.run_client(region="com")
        self.assertTrue(result["ok"], result)

    def test_missing_key_has_no_network(self):
        result, requests = self.run_client(key="")
        self.assertFalse(result["ok"])
        self.assertEqual(requests, [])

    def test_invalid_image_has_no_network(self):
        result, requests = self.run_client(mode="invalid_image")
        self.assertFalse(result["ok"])
        self.assertEqual(requests, [])

    def test_failed_remote_task_and_safe_gateway_error(self):
        for mode in ("failed", "remote_cancel", "gateway_failure", "oversize"):
            with self.subTest(mode=mode):
                result, _ = self.run_client(mode=mode)
                self.assertFalse(result["ok"], result)
                self.assertNotIn("fixture-key", result["error"])

    def test_rejected_rig_shows_platform_reason(self):
        result, _ = self.run_client(mode="not_riggable")
        self.assertFalse(result["ok"], result)
        self.assertIn("T-Pose", result["error"])
        self.assertIn("MODEL_NOT_RIGGABLE", result["error"])
        self.assertTrue(result.get("final"), result)

    def test_resume_rig_never_creates_paid_task(self):
        result, requests = self.run_client(resume="200", stage="rig")
        self.assertTrue(result["ok"], result)
        self.assertFalse(any(method == "POST" for method, _ in requests))
        self.assertEqual(result["tasks"], [["200", "rig"]])

    def test_resume_generation_only_creates_rig(self):
        result, requests = self.run_client(resume="100")
        self.assertTrue(result["ok"], result)
        self.assertEqual([path for method, path in requests if method == "POST"], ["/lux3d/v1/animations/rig/task/create"])
        self.assertEqual(result["tasks"], [["100", "generate"], ["100", "rig_pending"], ["200", "rig"]])

    def test_local_cancel_and_timeout_keep_resume_id(self):
        for mode in ("cancel", "timeout"):
            with self.subTest(mode=mode):
                result, requests = self.run_client(mode=mode, resume="200", stage="rig")
                self.assertFalse(result["ok"], result)
                self.assertEqual(result["tasks"], [["200", "rig"]])
                self.assertFalse(any(method == "POST" for method, _ in requests))

    def test_malformed_upload_envelope_is_rejected(self):
        result, requests = self.run_client(mode="malformed_upload")
        self.assertFalse(result["ok"], result)
        self.assertFalse(any("img-to-3d" in path for _, path in requests))

    def test_malformed_token_and_status_return_safe_errors(self):
        for mode in ("malformed_token", "malformed_status"):
            with self.subTest(mode=mode):
                result, _ = self.run_client(mode=mode)
                self.assertFalse(result["ok"], result)

    def test_uncertain_create_warns_against_duplicate_paid_calls(self):
        for mode in ("uncertain_create", "uncertain_rig", "cancel_create"):
            with self.subTest(mode=mode):
                result, requests = self.run_client(mode=mode)
                self.assertFalse(result["ok"], result)
                self.assertIn("平台任务记录", result["error"])
                self.assertIn("避免重复", result["error"])
                self.assertEqual(sum("img-to-3d" in path for method, path in requests if method == "POST"), 1)

    def test_lost_create_response_marks_pending_and_cannot_be_resumed(self):
        for mode in ("uncertain_create", "uncertain_rig", "cancel_create"):
            with self.subTest(mode=mode):
                result, _ = self.run_client(mode=mode)
                self.assertFalse(result["ok"], result)
                pending = ["100", "rig_pending"] if mode == "uncertain_rig" else ["", "generate_pending"]
                self.assertTrue(result["tasks"], "Paid create must mark its pending stage before sending")
                self.assertEqual(result["tasks"][-1], pending)
                resumed, requests = self.run_client(resume=pending[0], stage=pending[1])
                self.assertFalse(resumed["ok"], resumed)
                self.assertIn("实际任务号", resumed["error"])
                self.assertEqual(requests, [])


if __name__ == "__main__":
    unittest.main()
