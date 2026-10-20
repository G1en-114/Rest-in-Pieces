"""上传本地 GLB 并创建 Lux3D 人形自动绑骨任务（需要 tools/.venv 里的官方 SDK）。

用法:
  tools/.venv/Scripts/python tools/rig.py <model.glb>
然后用 `python tools/aholo.py wait <taskId> --out ...` 等待并下载绑好骨的 GLB。
"""
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
    if "=" in line and not line.lstrip().startswith("#"):
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip())

from manycore.aholo_sdk_asset import create_asset_client  # noqa: E402
from manycore.aholo_sdk_lux3d import create_lux3d_client  # noqa: E402

url = create_asset_client().upload_file(sys.argv[1]).url
print("uploaded:", url)
print("taskId:", create_lux3d_client().humanoid_auto_rig.create(model_url=url))
