#!/bin/bash
# Open WebUI DB 백업/복원 엔트리포인트
# - 시작 시: /workplace/db_backup/webui.db → /app/backend/data/webui.db 복원
# - 10분 주기: Python sqlite3 backup API로 안전하게 /workplace/db_backup에 저장

set -euo pipefail

DB_PATH="/app/backend/data/webui.db"
BACKUP_PATH="/workplace/db_backup/webui.db"
INTERVAL=600  # 10분

# DB 복원
restore_db() {
    mkdir -p /app/backend/data
    mkdir -p /workplace/db_backup

    if [ -f "${BACKUP_PATH}" ]; then
        echo "[backup] Restoring DB from backup..."
        python3 -c "
import sqlite3
src = sqlite3.connect('${BACKUP_PATH}')
dst = sqlite3.connect('${DB_PATH}')
src.backup(dst)
dst.close()
src.close()
print('[backup] DB restored successfully.')
"
    else
        echo "[backup] No backup found. Starting fresh."
    fi
}

# DB 백업 (sqlite3 backup API — DB가 사용 중이어도 안전)
backup_db() {
    if [ ! -f "${DB_PATH}" ]; then
        echo "[backup] WARN: DB file not found, skipping."
        return
    fi

    python3 -c "
import sqlite3
src = sqlite3.connect('${DB_PATH}')
dst = sqlite3.connect('${BACKUP_PATH}')
src.backup(dst)
dst.close()
src.close()
print('[backup] DB backup complete.')
"
}

# 주기적 백업 루프 (백그라운드 실행)
backup_loop() {
    while true; do
        sleep "${INTERVAL}"
        echo "[backup] Running scheduled DB backup (interval: ${INTERVAL}s)..."
        backup_db
    done
}

# ── 메인 ──────────────────────────────────────────────────────────────────────

restore_db

backup_loop &

# Open WebUI 기본 시작 스크립트 실행
exec bash /app/backend/start.sh
