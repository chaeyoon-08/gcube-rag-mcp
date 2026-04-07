# RAG Chat & MCP Agent Stack

gcube 멀티 컨테이너 환경에서 RAG 기반 챗봇 + MCP 파일 에이전트를 구성하는 커스텀 이미지 저장소입니다.

---

## 구조

```
.
├── webui/          # Open WebUI 커스텀 이미지 (로케일 + 백업 로직 내장)
├── ollama/         # Ollama 커스텀 이미지 (모델 pull 스크립트 내장)
├── mcp/            # MCP Agent 이미지 (mcpo 기반 파일시스템 서버)
└── .github/
    └── workflows/  # 이미지별 GHCR 빌드 워크플로우
```

---

## 이미지 목록

| 이미지 | 베이스 | 역할 |
|---|---|---|
| `ghcr.io/{org}/rag-webui:latest` | `open-webui/open-webui` | 사용자 UI (포트 8080) |
| `ghcr.io/{org}/rag-ollama:latest` | `ollama/ollama` | LLM + 임베딩 서버 (포트 11434) |
| `ghcr.io/{org}/rag-mcp:latest` | `python:3.11-slim` | MCP 파일 에이전트 (포트 8000) |
| `qdrant/qdrant:latest` | — | 벡터 DB (포트 6333/6334) |

> qdrant는 공식 이미지를 직접 사용합니다.

---

## 빌드 트리거

각 이미지는 해당 디렉토리 변경 시 자동으로 빌드됩니다.

- `webui/**` 변경 → `build-webui.yml` 실행
- `ollama/**` 변경 → `build-ollama.yml` 실행
- `mcp/**` 변경 → `build-mcp.yml` 실행

`workflow_dispatch`로 수동 실행도 가능합니다.

---

## 환경변수 (gcube 워크로드 설정 시)

### rag-webui

| KEY | VALUE |
|---|---|
| `DATA_DIR` | `/app/backend/data` |
| `UPLOAD_DIR` | `/workplace/service_v1/uploads` |
| `WEBUI_SECRET_KEY` | *(랜덤 문자열 생성)* |
| `OLLAMA_BASE_URL` | `http://localhost:11434` |
| `QDRANT_URI` | `http://localhost:6333` |
| `VECTOR_DB` | `qdrant` |
| `DEFAULT_MODELS` | `llama3.1:8b` |
| `RAG_EMBEDDING_ENGINE` | `ollama` |
| `RAG_EMBEDDING_MODEL` | `nomic-embed-text` |
| `RAG_EMBEDDING_CHUNK_SIZE` | `1000` |
| `RAG_EMBEDDING_BATCH_SIZE` | `2` |
| `ENABLE_RAG_WEB_SEARCH` | `true` |
| `ENABLE_OCR` | `true` |
| `OCR_ENGINE` | `tesseract` |
| `OCR_LANG` | `kor+eng` |
| `RAG_FAIL_ON_ERROR` | `false` |
| `TIMEOUT` / `UPLOAD_TIMEOUT` | `3600` |
| `OLLAMA_REQUEST_TIMEOUT` | `1800` |
| `FILE_UPLOAD_MAX_SIZE` | `2147483648` |
| `MAX_CONTENT_LENGTH` | `2147483648` |
| `ENABLE_CHUNKED_UPLOAD` | `true` |

### rag-ollama

| KEY | VALUE |
|---|---|
| `OLLAMA_HOST` | `0.0.0.0` |
| `OLLAMA_KEEP_ALIVE` | `5m` |
| `OLLAMA_NUM_PARALLEL` | `4` |

### rag-mcp

| KEY | VALUE |
|---|---|
| `NODE_ENV` | `production` |

### qdrant

| KEY | VALUE |
|---|---|
| `QDRANT__SERVICE__GRPC_PORT` | `6334` |

---

## MCP 설정 (mcp/config.json)

`/workplace`를 파일시스템 루트로 노출합니다.
gcube 개인 저장소를 `/workplace`에 마운트하면 MCP 에이전트가 해당 파일에 접근합니다.

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/workplace"]
    }
  }
}
```

---

## Open WebUI에서 MCP 연동

1. 관리자 패널 → 설정 → 외부 도구 → 도구 서버 관리 `+`
2. URL: `http://localhost:8000` (또는 MCP 컨테이너 외부 접속 URL)
3. 이름: `Files_Agent`
4. 저장 후 채팅에서 도구 선택하여 사용
