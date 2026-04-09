#!/bin/bash
# Qdrant 스냅샷 관리 스크립트
# - 시작 시: /workplace/snapshots 에 저장된 스냅샷을 Qdrant로 복원
# - 10분 주기: 모든 컬렉션 스냅샷을 /workplace/snapshots 에 저장

set -euo pipefail

QDRANT_URL="http://localhost:6333"
SNAPSHOT_DIR="/workplace/snapshots"
INTERVAL=600  # 10분

# Qdrant가 완전히 뜰 때까지 대기
wait_for_qdrant() {
    echo "[snapshot] Waiting for Qdrant to be ready..."
    for i in $(seq 1 30); do
        if curl -sf "${QDRANT_URL}/readyz" > /dev/null 2>&1; then
            echo "[snapshot] Qdrant is ready."
            return 0
        fi
        sleep 2
    done
    echo "[snapshot] ERROR: Qdrant did not become ready in time."
    exit 1
}

# /snapshots 에 있는 .snapshot 파일을 컬렉션별로 복원
restore_snapshots() {
    mkdir -p "${SNAPSHOT_DIR}"
    echo "[snapshot] Checking for snapshots to restore in ${SNAPSHOT_DIR}..."
    local restored=0

    for snapshot_file in "${SNAPSHOT_DIR}"/*.snapshot; do
        [ -f "${snapshot_file}" ] || continue

        # 파일명에서 컬렉션 이름 추출: {collection_name}_{timestamp}.snapshot
        local filename
        filename=$(basename "${snapshot_file}")
        # 마지막 _ 이후(타임스탬프+.snapshot)를 제거해 컬렉션 이름 추출
        local collection_name
        collection_name=$(echo "${filename}" | sed 's/_[^_]*\.snapshot$//')

        echo "[snapshot] Restoring collection '${collection_name}' from ${filename}..."
        local response
        response=$(curl -sf -X PUT "${QDRANT_URL}/collections/${collection_name}/snapshots/recover" \
            -H "Content-Type: application/json" \
            -d "{\"location\": \"file://${snapshot_file}\", \"priority\": \"snapshot\"}" \
            2>&1) || true

        if echo "${response}" | grep -q '"status":"ok"'; then
            echo "[snapshot] Restored '${collection_name}' successfully."
            restored=$((restored + 1))
        else
            echo "[snapshot] WARN: Failed to restore '${collection_name}': ${response}"
        fi
    done

    if [ "${restored}" -eq 0 ]; then
        echo "[snapshot] No snapshots found to restore. Starting fresh."
    fi
}

# 모든 컬렉션의 스냅샷을 생성하고 /snapshots 에 저장
save_snapshots() {
    mkdir -p "${SNAPSHOT_DIR}"
    # 컬렉션 목록 조회
    local collections_json
    collections_json=$(curl -sf "${QDRANT_URL}/collections" 2>/dev/null) || {
        echo "[snapshot] WARN: Failed to get collections list."
        return
    }

    local collections
    collections=$(echo "${collections_json}" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//')

    if [ -z "${collections}" ]; then
        echo "[snapshot] No collections found, skipping snapshot."
        return
    fi

    for collection in ${collections}; do
        echo "[snapshot] Creating snapshot for collection '${collection}'..."
        local response
        response=$(curl -sf -X POST "${QDRANT_URL}/collections/${collection}/snapshots" \
            -H "Content-Type: application/json" \
            2>/dev/null) || {
            echo "[snapshot] WARN: Failed to create snapshot for '${collection}'."
            continue
        }

        # 생성된 스냅샷 파일명 추출
        local snapshot_name
        snapshot_name=$(echo "${response}" | grep -o '"name":"[^"]*"' | head -1 | sed 's/"name":"//;s/"//')

        if [ -z "${snapshot_name}" ]; then
            echo "[snapshot] WARN: Could not parse snapshot name for '${collection}'."
            continue
        fi

        # Qdrant 내부 스냅샷 경로에서 /snapshots 로 복사
        # QDRANT__STORAGE__SNAPSHOTS_PATH=/qdrant/snapshots (기본값)
        local src="/qdrant/snapshots/${collection}/${snapshot_name}"
        local dst="${SNAPSHOT_DIR}/${collection}_latest.snapshot"

        if [ -f "${src}" ]; then
            cp "${src}" "${dst}"
            echo "[snapshot] Saved '${collection}' snapshot to ${dst}."
        else
            echo "[snapshot] WARN: Snapshot file not found at ${src}."
        fi
    done
}

# 주기적 스냅샷 루프 (백그라운드 실행용)
snapshot_loop() {
    while true; do
        sleep "${INTERVAL}"
        echo "[snapshot] Running scheduled snapshot (interval: ${INTERVAL}s)..."
        save_snapshots
    done
}

# ── 메인 ──────────────────────────────────────────────────────────────────────

# Qdrant를 백그라운드로 실행
echo "[snapshot] Starting Qdrant..."
/qdrant/qdrant &
QDRANT_PID=$!

# Qdrant 준비 대기
wait_for_qdrant

# 스냅샷 복원
restore_snapshots

# 주기적 스냅샷 루프 백그라운드 실행
snapshot_loop &

# Qdrant 프로세스가 종료되면 컨테이너도 종료
wait "${QDRANT_PID}"
