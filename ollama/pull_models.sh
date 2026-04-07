#!/usr/bin/env bash
set -euo pipefail

# Ollama 서버 기동
ollama serve &
SERVER_PID=$!

# 서버 준비 대기
echo "[ollama] Waiting for server..."
until curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; do
    sleep 2
done
echo "[ollama] Server ready."

# 모델 pull
# nomic-embed-text: 다국어 임베딩 모델 (RAG용)
ollama pull nomic-embed-text

# llama3.1:8b: 추론 모델
# 한국어 성능 향상이 필요하면 llama3.1:8b 대신 qwen2.5:7b 고려
ollama pull llama3.1:8b

echo "[ollama] All models pulled. Server running (PID=${SERVER_PID})."
wait "${SERVER_PID}"
