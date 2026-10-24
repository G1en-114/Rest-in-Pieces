"""把 docs/提交/ 下的 Markdown（试玩文档、作品说明）排版成 PDF，用 Edge 无头打印。

  python tools/submit_docs.py   # 生成 build/提交材料/试玩文档.pdf、作品说明.pdf
"""
import subprocess
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs" / "提交"
OUT = ROOT / "build" / "提交材料"
EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
FONT = (ROOT / "game/assets/fonts/ZCOOLKuaiLe-Regular.ttf").as_uri()

CSS = """
@font-face { font-family: KuaiLe; src: url('%s'); }
@page { size: A4; margin: 16mm 15mm; }
body { font-family: 'Microsoft YaHei', 'PingFang SC', sans-serif; font-size: 10.5pt; line-height: 1.65;
       color: #2a2230; }
h1 { font-family: KuaiLe, sans-serif; font-weight: normal; font-size: 26pt; color: #2a2230; margin: 0 0 8px;
     padding-bottom: 6px; border-bottom: 4px solid #ffd54a; }
h2 { font-family: KuaiLe, sans-serif; font-weight: normal; font-size: 16pt; color: #c2185b; margin: 20px 0 6px;
     break-after: avoid; }
p { margin: 6px 0; }
strong { color: #1f1a24; }
blockquote { margin: 10px 0; padding: 8px 14px; background: #fff6d6; border-left: 5px solid #ffb300;
             border-radius: 6px; }
table { border-collapse: collapse; width: 100%%; margin: 8px 0; font-size: 10pt; }
tr { break-inside: avoid; }
th { background: #2a2230; color: #fff; font-weight: normal; text-align: left; }
th, td { padding: 5px 9px; border: 1px solid #ddd3e0; vertical-align: top; }
tr:nth-child(even) td { background: #faf6fb; }
img { width: 100%%; border-radius: 8px; margin: 4px 0 6px; }
code { font-family: Consolas, monospace; font-size: 9.5pt; background: #f2edf4; padding: 1px 4px;
       border-radius: 3px; }
""" % FONT


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for md in sorted(SRC.glob("*.md")):
        body = markdown.markdown(md.read_text(encoding="utf-8"), extensions=["tables"])
        html = SRC / f"_{md.stem}.html"  # 和 md 放一起，图片的相对路径才对
        html.write_text(f"<!doctype html><html lang='zh-CN'><head><meta charset='utf-8'><style>{CSS}</style>"
                        f"</head><body>{body}</body></html>", encoding="utf-8")
        pdf = OUT / f"{md.stem}.pdf"
        subprocess.run([EDGE, "--headless", "--disable-gpu", "--no-pdf-header-footer",
                        f"--print-to-pdf={pdf}", html.as_uri()], capture_output=True, timeout=120)
        html.unlink()
        print(pdf, f"{pdf.stat().st_size / 1e3:.0f} KB")


if __name__ == "__main__":
    main()
