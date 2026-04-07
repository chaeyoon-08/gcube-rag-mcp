#!/usr/bin/env bash
set -euo pipefail

DATA_STORE="/workplace/service_v1/data"
UPLOAD_STORE="/workplace/service_v1/uploads/uploads"
APP_DATA="/app/backend/data"

# 업로드 디렉토리 확보
mkdir -p "${APP_DATA}/uploads"

# DB 복구
if [ -f "${DATA_STORE}/webui.db" ]; then
    echo "[restore] DB found — restoring..."
    cp -f "${DATA_STORE}/webui.db" "${APP_DATA}/webui.db"
fi

# 업로드 파일 복구
if [ -d "${UPLOAD_STORE}" ]; then
    echo "[restore] Uploads found — restoring..."
    cp -rf "${UPLOAD_STORE}/." "${APP_DATA}/uploads/"
fi

chmod -R 777 "${APP_DATA}"
echo "[restore] Complete."

# 백그라운드 백업 루프 (5분 주기)
(
    while true; do
        sleep 300
        DB_SIZE=$(stat -c%s "${APP_DATA}/webui.db" 2>/dev/null || echo 0)
        if [ "${DB_SIZE}" -gt 500000 ]; then
            mkdir -p "${DATA_STORE}" "${UPLOAD_STORE}"
            cp -f  "${APP_DATA}/webui.db"     "${DATA_STORE}/"
            cp -rf "${APP_DATA}/uploads/."    "${UPLOAD_STORE}/"
            echo "[backup] Done."
        else
            echo "[backup] Data too small, skipping."
        fi
    done
) &

exec /app/backend/start.sh
