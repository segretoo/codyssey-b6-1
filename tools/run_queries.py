#!/usr/bin/env python3
"""schema.sql → seed.sql 로 DB를 새로 만들고, queries.sql / bonus.sql 을 쿼리별로 실행해서
결과를 results/ 폴더에 텍스트로 저장하는 보조 스크립트. (표준 라이브러리 sqlite3만 사용)

사용법:  python3 tools/run_queries.py
"""
import re
import sqlite3
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / "results"
MARKER = re.compile(r"^-- \[([QB]\d+(?:-[\w]+)?)\]\s*(.*)$")


def width(s: str) -> int:
    """한글(전각) 문자는 화면에서 2칸이라 표 정렬을 위해 표시 폭을 따로 계산한다."""
    return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in s)


def pad(s: str, w: int, right: bool = False) -> str:
    gap = " " * (w - width(s))
    return gap + s if right else s + gap


def render(cols, rows) -> str:
    if not cols:
        return ""
    cells = [["NULL" if v is None else str(v) for v in r] for r in rows]
    widths = [max([width(c)] + [width(r[i]) for r in cells]) for i, c in enumerate(cols)]
    num = [all(isinstance(r[i], (int, float)) for r in rows if r[i] is not None) and bool(rows) for i in range(len(cols))]
    head = " | ".join(pad(c, widths[i], num[i]) for i, c in enumerate(cols))
    line = "-+-".join("-" * w for w in widths)
    body = [" | ".join(pad(r[i], widths[i], num[i]) for i in range(len(cols))) for r in cells]
    return "\n".join([head, line, *body, f"({len(rows)} row{'s' if len(rows) != 1 else ''})"])


def new_db() -> sqlite3.Connection:
    # isolation_level=None → 문장마다 즉시 커밋 (sqlite3 CLI와 같은 동작, PRAGMA도 바로 적용됨)
    con = sqlite3.connect(":memory:", isolation_level=None)
    con.executescript((ROOT / "schema.sql").read_text(encoding="utf-8"))
    con.executescript((ROOT / "seed.sql").read_text(encoding="utf-8"))
    return con


def split_blocks(text: str):
    pre, blocks, cur = [], [], None
    for line in text.splitlines():
        m = MARKER.match(line)
        if m:
            cur = {"id": m.group(1), "title": m.group(2), "lines": []}
            blocks.append(cur)
        elif cur is None:
            pre.append(line)
        else:
            cur["lines"].append(line)
    return "\n".join(pre), blocks


def run_block(con, block) -> str:
    # 블록 맨 끝의 빈 줄/주석은 다음 섹션 제목이 딸려온 것이므로 출력에서 뺀다
    lines = list(block["lines"])
    while lines and (not lines[-1].strip() or lines[-1].lstrip().startswith("--")):
        lines.pop()
    sql_text = "\n".join(lines).strip("\n")
    out = [f"[{block['id']}] {block['title']}", "=" * 70, sql_text, "-" * 70]
    buf = ""
    for line in lines:
        if not buf and (not line.strip() or line.lstrip().startswith("--")):
            continue
        buf += line + "\n"
        if sqlite3.complete_statement(buf):
            stmt = buf.strip()
            buf = ""
            try:
                cur = con.execute(stmt)
                if cur.description:
                    cols = [d[0] for d in cur.description]
                    out.append(render(cols, cur.fetchall()))
                elif stmt.upper().startswith(("INSERT", "UPDATE", "DELETE")):
                    out.append(f"OK — {cur.rowcount} row(s) affected")
                else:
                    out.append("OK")
            except sqlite3.Error as e:
                out.append(f"ERROR: {e}")
            out.append("")
    return "\n".join(out).rstrip() + "\n"


def run_file(sql_path: Path, file_prefix: str, all_name: str):
    con = new_db()
    pre, blocks = split_blocks(sql_path.read_text(encoding="utf-8"))
    con.executescript(pre)  # PRAGMA 등 공통 준비
    texts = []
    for b in blocks:
        text = run_block(con, b)
        (RESULTS / f"{file_prefix}{b['id'].lower()}.txt").write_text(text, encoding="utf-8")
        texts.append(text)
    (RESULTS / all_name).write_text("\n\n".join(texts), encoding="utf-8")
    con.close()
    return len(blocks)


if __name__ == "__main__":
    RESULTS.mkdir(exist_ok=True)
    for old in RESULTS.glob("*.txt"):
        old.unlink()
    n_q = run_file(ROOT / "queries.sql", "", "00_all_queries.txt")
    n_b = run_file(ROOT / "bonus.sql", "bonus_", "00_all_bonus.txt")
    print(f"queries: {n_q} blocks, bonus: {n_b} blocks → {RESULTS}")
