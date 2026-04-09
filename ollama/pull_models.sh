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

# EMBEDDING_MODEL: 임베딩 모델 (먼저 pull → Ollama 목록 하단에 표시)
if [ -z "${EMBEDDING_MODEL:-}" ]; then
    echo "[ollama] EMBEDDING_MODEL not set — skipping embedding model pull."
else
    echo "[ollama] Pulling embedding model: ${EMBEDDING_MODEL}"
    ollama pull "${EMBEDDING_MODEL}"
    echo "[ollama] Embedding model pulled."
fi

# CHAT_MODELS: 채팅 모델 (콤마 구분, 나중에 pull → Ollama 목록 상단에 표시)
if [ -z "${CHAT_MODELS:-}" ]; then
    echo "[ollama] CHAT_MODELS not set — skipping chat model pull."
else
    IFS=',' read -ra MODELS <<< "${CHAT_MODELS}"
    for MODEL in "${MODELS[@]}"; do
        MODEL="$(echo "${MODEL}" | xargs)"  # 앞뒤 공백 제거
        if [ -n "${MODEL}" ]; then
            echo "[ollama] Pulling chat model: ${MODEL}"
            ollama pull "${MODEL}"
        fi
    done
    echo "[ollama] All chat models pulled."
fi

echo "[ollama] Server running (PID=${SERVER_PID})."
wait "${SERVER_PID}"
