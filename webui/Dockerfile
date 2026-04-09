ARG BASE_VERSION=v0.8.12
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
# DATA_DIR은 로컬 디스크 유지 (FUSE 마운트 금지 — SQLite 손상 원인), 기본값 그대로 사용
# UPLOAD_DIR은 v0.8.6에서 env var를 읽지 않으므로 patch_files.py로 config.py를 패치해 활성화
# 패치 후 이 값이 실제로 적용되어 업로드 파일이 Dropbox(/workplace/service_v1/uploads)에 저장됨
ENV UPLOAD_DIR=/workplace/service_v1/uploads

# ── Ollama / Qdrant 연결 (gcube 동일 워크로드 내 localhost 공유) ────────────
ENV OLLAMA_BASE_URL=http://localhost:11434 \
    OLLAMA_REQUEST_TIMEOUT=1800 \
    QDRANT_URI=http://localhost:6333 \
    VECTOR_DB=qdrant

# ── RAG 설정 ─────────────────────────────────────────────────────────────────
ENV RAG_EMBEDDING_ENGINE=ollama \
    RAG_EMBEDDING_MODEL=qwen3-embedding:8b \
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

# ── FUSE(Dropbox) 마운트된 SQLite에서 db.refresh() 실패 패치 ─────────────────
# SQLAlchemy의 db.refresh()는 FUSE 파일시스템에서 세션 내부 상태를 찾지 못해 실패함.
# INSERT 후 db.refresh() 대신 db.expire() + db.get()으로 대체하여 안정적으로 조회.
# 패턴 불일치 또는 구문 오류 시 빌드를 즉시 실패시킴 (silent skip 방지).
COPY patch_files.py /tmp/patch_files.py
RUN python3 /tmp/patch_files.py && rm /tmp/patch_files.py

# ── DB 백업/복원 엔트리포인트 ────────────────────────────────────────────────
# /app/backend/data는 로컬 디스크에 유지 (FUSE 마운트 금지 — SQLite 손상 원인)
# /db_backup (Dropbox 마운트)에 10분 주기로 DB 백업, 시작 시 복원
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
