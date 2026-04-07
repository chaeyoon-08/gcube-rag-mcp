#!/usr/bin/env bash
set -euo pipefail

# Ollama 서버 기동
ollama serve &
SERVER_PID=$!

# 서버 준비 대기 (ollama 베이스 이미지에 curl 미포함 → ollama list로 대체)
echo "[ollama] Waiting for server..."
until ollama list > /dev/null 2>&1; do
    sleep 2
done
echo "[ollama] Server ready."

# OLLAMA_MODELS 환경변수에서 모델 목록 읽기 (콤마 구분)
if [ -z "${OLLAMA_MODELS:-}" ]; then
    echo "[ollama] OLLAMA_MODELS not set — skipping model pull."
else
    IFS=',' read -ra MODELS <<< "${OLLAMA_MODELS}"
    for MODEL in "${MODELS[@]}"; do
        MODEL="$(echo "${MODEL}" | xargs)"  # 앞뒤 공백 제거
        if [ -n "${MODEL}" ]; then
            echo "[ollama] Pulling model: ${MODEL}"
            ollama pull "${MODEL}"
        fi
    done
    echo "[ollama] All models pulled."
fi

echo "[ollama] Server running (PID=${SERVER_PID})."
wait "${SERVER_PID}"
