"""
open_webui/models/files.py 패치 스크립트
- 대상: v0.8.6
- 목적: FUSE(Dropbox) 마운트 SQLite에서 db.refresh() 실패 시 fallback

db.commit() → db.refresh(result) → if result: 라는 3줄 컨텍스트로 패턴을 유일하게 특정.
"""
import pathlib, sys, ast

target = pathlib.Path("/app/backend/open_webui/models/files.py")
src = target.read_text()

# v0.8.6 실제 소스 기준 (16칸 들여쓰기, 3줄 컨텍스트로 유일 특정)
old = (
    "                db.commit()\n"
    "                db.refresh(result)\n"
    "                if result:"
)
new = (
    "                db.commit()\n"
    "                try:\n"
    "                    db.refresh(result)\n"
    "                except Exception:\n"
    "                    db.expire(result)\n"
    "                    result = db.get(File, result.id)\n"
    "                if result:"
)

count = src.count(old)
if count == 0:
    print("ERROR: pattern not found", file=sys.stderr)
    sys.exit(1)
if count > 1:
    print(f"ERROR: pattern matched {count} times (expected 1)", file=sys.stderr)
    sys.exit(1)

patched = src.replace(old, new)

try:
    ast.parse(patched)
except SyntaxError as e:
    print(f"ERROR: syntax error after patch: {e}", file=sys.stderr)
    sys.exit(1)

target.write_text(patched)
print("patch applied and syntax verified")
