"""AHOLO Lux3D 命令行小工具（只用标准库）。

key 从环境变量或仓库根目录的 .env 读取（AHOLO_API_KEY），环境变量优先。

用法:
  python tools/aholo.py text3d "提示词" [--style cartoon] [--version G1] [--faces 20000]
  python tools/aholo.py rig <GLB 的公网 URL>
  python tools/aholo.py wait <taskId> [--out generated/xxx] [--timeout 900]
"""
import argparse
import json
import math
import os
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATUS = {0: "初始化", 1: "进行中", 3: "成功", 4: "失败", 6: "已取消"}


def load_env():
    env = {}
    path = ROOT / ".env"
    lines = path.read_text(encoding="utf-8-sig").splitlines() if path.exists() else []
    for line in lines:
        if "=" in line and not line.lstrip().startswith("#"):
            k, v = line.split("=", 1)
            v = v.strip()
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
                v = v[1:-1]
            env[k.strip()] = v
    for key in ("AHOLO_API_KEY", "AHOLO_BASE_URL"):
        if key in os.environ:
            env[key] = os.environ[key]
    return env


def call(method, path, body=None, timeout=60):
    env = load_env()
    key = env.get("AHOLO_API_KEY", "").strip()
    if not key:
        sys.exit("缺少 AHOLO_API_KEY：请设置环境变量或仓库根目录的 .env。")
    base = env.get("AHOLO_BASE_URL", "https://api.aholo3d.cn").rstrip("/")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base + path, data=data, method=method, headers={
        "Authorization": key,
        "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req, timeout=timeout) as r:
        resp = json.loads(r.read().decode("utf-8"))
    if resp.get("c") != "0":
        sys.exit(f"API 错误: {json.dumps(resp, ensure_ascii=False)}")
    return resp["d"]


def text3d(a):
    body = {"prompt": a.prompt, "style": a.style, "version": a.version, "faceCount": a.faces}
    print("taskId:", call("POST", "/lux3d/v1/generate/text-to-3d/task/create", body))


def rig(a):
    print("taskId:", call("POST", "/lux3d/v1/animations/rig/task/create", {"modelUrl": a.url}))


def wait(a):
    start = time.monotonic()
    deadline = start + a.timeout
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            sys.exit(f"等待任务 {a.task} 超时（{a.timeout:g} 秒）；可用同一 taskId 重新 wait。")
        try:
            d = call("GET", f"/lux3d/v1/generate/task/get?taskid={a.task}",
                     timeout=min(60, remaining))
        except TimeoutError:
            sys.exit(f"查询任务 {a.task} 超时；可用同一 taskId 重新 wait。")
        st = d.get("status")
        print(f"[{time.monotonic() - start:5.0f}s] {STATUS.get(st, st)}", flush=True)
        if st not in (0, 1):
            break
        time.sleep(min(10, max(0, deadline - time.monotonic())))
    out = ROOT / (a.out or f"generated/{a.task}")
    out.mkdir(parents=True, exist_ok=True)
    (out / "task.json").write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
    for i, o in enumerate(d.get("outputs") or []):
        url = o.get("content", "")
        if not url.startswith("http"):
            print(f"output[{i}]: {url}")
            continue
        name = f"{i}_" + url.split("?")[0].rsplit("/", 1)[-1]
        urllib.request.urlretrieve(url, out / name)
        print(f"output[{i}] -> {out / name}")
    if st != 3:
        sys.exit(1)


def positive_seconds(value):
    seconds = float(value)
    if not math.isfinite(seconds) or seconds <= 0:
        raise argparse.ArgumentTypeError("超时秒数必须是有限正数")
    return seconds


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(required=True)
    t = sub.add_parser("text3d")
    t.add_argument("prompt")
    t.add_argument("--style", default="cartoon")
    t.add_argument("--version", default="G1")
    t.add_argument("--faces", type=int, default=20000)
    t.set_defaults(fn=text3d)
    r = sub.add_parser("rig")
    r.add_argument("url")
    r.set_defaults(fn=rig)
    w = sub.add_parser("wait")
    w.add_argument("task")
    w.add_argument("--out")
    w.add_argument("--timeout", type=positive_seconds, default=900,
                   help="等待生成完成的最大秒数，默认 900；不包含结果下载")
    w.set_defaults(fn=wait)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
