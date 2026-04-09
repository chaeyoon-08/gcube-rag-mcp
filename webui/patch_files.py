"""
Open WebUI v0.8.12 패치 스크립트

[패치 1] open_webui/models/files.py
- 목적: FUSE(Dropbox) 마운트 SQLite에서 db.refresh() 실패 시 fallback
- 패턴: db.commit() + db.refresh(result) + if result: (16칸 들여쓰기, 3줄 컨텍스트)

[패치 2] open_webui/config.py
- 목적: UPLOAD_DIR을 DATA_DIR 고정 파생 대신 환경변수로 독립 설정 가능하게 함
- 배경: v0.8.6에서 UPLOAD_DIR env var를 읽지 않고 DATA_DIR / "uploads"로 고정됨
- 패턴: UPLOAD_DIR = DATA_DIR / "uploads" (2줄 컨텍스트, 유일)
"""
import pathlib, sys, ast

# ──────────────────────────────────────────────────────────────────────────────
# 패치 1: models/files.py — db.refresh() fallback
# ──────────────────────────────────────────────────────────────────────────────

target1 = pathlib.Path("/app/backend/open_webui/models/files.py")
src1 = target1.read_text()

old1 = (
    "                db.commit()\n"
    "                db.refresh(result)\n"
    "                if result:"
)
new1 = (
    "                db.commit()\n"
    "                try:\n"
    "                    db.refresh(result)\n"
    "                except Exception:\n"
    "                    db.expire(result)\n"
    "                    result = db.get(File, result.id)\n"
    "                if result:"
)

count1 = src1.count(old1)
if count1 == 0:
    print("ERROR [patch1]: pattern not found in files.py", file=sys.stderr)
    sys.exit(1)
if count1 > 1:
    print(f"ERROR [patch1]: pattern matched {count1} times (expected 1)", file=sys.stderr)
    sys.exit(1)

patched1 = src1.replace(old1, new1)

try:
    ast.parse(patched1)
except SyntaxError as e:
    print(f"ERROR [patch1]: syntax error after patch: {e}", file=sys.stderr)
    sys.exit(1)

target1.write_text(patched1)
print("[patch1] files.py: db.refresh() fallback applied")

# ──────────────────────────────────────────────────────────────────────────────
# 패치 2: config.py — UPLOAD_DIR 환경변수 독립 설정
# ──────────────────────────────────────────────────────────────────────────────

target2 = pathlib.Path("/app/backend/open_webui/config.py")
src2 = target2.read_text()

old2 = (
    "UPLOAD_DIR = DATA_DIR / 'uploads'\n"
    "UPLOAD_DIR.mkdir(parents=True, exist_ok=True)"
)
new2 = (
    "UPLOAD_DIR = Path(os.getenv(\"UPLOAD_DIR\", DATA_DIR / \"uploads\")).resolve()\n"
    "UPLOAD_DIR.mkdir(parents=True, exist_ok=True)"
)

count2 = src2.count(old2)
if count2 == 0:
    print("ERROR [patch2]: pattern not found in config.py", file=sys.stderr)
    sys.exit(1)
if count2 > 1:
    print(f"ERROR [patch2]: pattern matched {count2} times (expected 1)", file=sys.stderr)
    sys.exit(1)

patched2 = src2.replace(old2, new2)

try:
    ast.parse(patched2)
except SyntaxError as e:
    print(f"ERROR [patch2]: syntax error after patch: {e}", file=sys.stderr)
    sys.exit(1)

target2.write_text(patched2)
print("[patch2] config.py: UPLOAD_DIR env var support applied")
