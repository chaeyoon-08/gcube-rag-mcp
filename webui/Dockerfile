ARG BASE_VERSION=v0.6.5
FROM ghcr.io/open-webui/open-webui:${BASE_VERSION}

# 한국어 로케일, 폰트, Tesseract OCR 설치
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      locales \
      fonts-nanum \
      tesseract-ocr \
      tesseract-ocr-kor \
 && echo 'ko_KR.UTF-8 UTF-8' > /etc/locale.gen \
 && locale-gen \
 && rm -rf /var/lib/apt/lists/*

# ── 로케일 ──────────────────────────────────────────────────────────────────
ENV LANG=ko_KR.UTF-8 \
    LC_ALL=ko_KR.UTF-8 \
    PYTHONIOENCODING=utf-8

# ── 데이터 경로 ──────────────────────────────────────────────────────────────
# DATA_DIR은 dropbox-storage를 /app/backend/data 에 직접 마운트하므로 기본값 유지
# UPLOAD_DIR은 dropbox-storage 마운트 경로에 직접 씀
ENV UPLOAD_DIR=/workplace/service_v1/uploads

# ── Ollama / Qdrant 연결 (gcube 동일 워크로드 내 localhost 공유) ────────────
ENV OLLAMA_BASE_URL=http://localhost:11434 \
    OLLAMA_REQUEST_TIMEOUT=1800 \
    QDRANT_URI=http://localhost:6333 \
    VECTOR_DB=qdrant

# ── 기본 모델 ────────────────────────────────────────────────────────────────
ENV DEFAULT_MODELS=qwen3:8b

# ── RAG 설정 ─────────────────────────────────────────────────────────────────
ENV RAG_EMBEDDING_ENGINE=ollama \
    RAG_EMBEDDING_MODEL=nomic-embed-text \
    RAG_EMBEDDING_CHUNK_SIZE=1000 \
    RAG_EMBEDDING_BATCH_SIZE=2 \
    RAG_FAIL_ON_ERROR=false \
    ENABLE_RAG_WEB_SEARCH=true

# ── OCR 설정 ─────────────────────────────────────────────────────────────────
ENV ENABLE_OCR=true \
    OCR_ENGINE=tesseract \
    OCR_LANG=kor+eng \
    PDF_EXTRACT_IMAGES=false

# ── 업로드 / 타임아웃 ────────────────────────────────────────────────────────
ENV FILE_UPLOAD_MAX_SIZE=2147483648 \
    MAX_CONTENT_LENGTH=2147483648 \
    ENABLE_CHUNKED_UPLOAD=true \
    TIMEOUT=3600 \
    UPLOAD_TIMEOUT=3600

# ── WEBUI_SECRET_KEY 는 gcube 환경변수에서 반드시 직접 설정 ──────────────────
# 미설정 시 재배포마다 JWT 토큰이 무효화되어 로그인 세션이 초기화됩니다.

# 커스텀 ENTRYPOINT 불필요 — 베이스 이미지 기본 시작 스크립트(/app/backend/start.sh) 그대로 사용
