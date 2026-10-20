"""AHOLO Lux3D 命令行小工具（只用标准库）。

key 从仓库根目录的 .env 读取（AHOLO_API_KEY），不要写进代码。

用法:
  python tools/aholo.py text3d "提示词" [--style cartoon] [--version G1] [--faces 20000]
  python tools/aholo.py rig <GLB 的公网 URL>
  python tools/aholo.py wait <taskId> [--out generated/xxx]   # 轮询直到结束并下载结果
"""
import argparse
import json
import os
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATUS = {0: "初始化", 1: "进行中", 3: "成功", 4: "失败", 6: "已取消"}


def load_env():
    env = {}
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()
    return env


ENV = load_env()
BASE = ENV.get("AHOLO_BASE_URL", "https://api.aholo3d.cn")


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method, headers={
        "Authorization": ENV["AHOLO_API_KEY"],
        "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req, timeout=60) as r:
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
    start = time.time()
    while True:
        d = call("GET", f"/lux3d/v1/generate/task/get?taskid={a.task}")
        st = d.get("status")
        print(f"[{time.time() - start:5.0f}s] {STATUS.get(st, st)}", flush=True)
        if st not in (0, 1):
            break
        time.sleep(10)
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
    w.set_defaults(fn=wait)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
