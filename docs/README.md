# rag-mcp-stack

Open WebUI + Ollama + Qdrant + MCP 기반 RAG 챗봇 및 파일 에이전트 스택입니다.
단일 워크로드에 4개 컨테이너를 등록하고 `WEBUI_SECRET_KEY`만 설정하면 배포가 완료됩니다.

---

## 이미지 목록

| 이미지 | 베이스 | 포트 | 역할 |
|---|---|---|---|
| `ghcr.io/chaeyoon-08/rag-webui:latest` | open-webui `v0.8.6` | 8080 | 사용자 UI (Open WebUI) |
| `ghcr.io/chaeyoon-08/rag-ollama:latest` | ollama `v0.20.2` | 11434 | LLM 및 임베딩 추론 서버 |
| `qdrant/qdrant:v1.17.0` | 공식 이미지 | 6333 | 벡터 데이터베이스 |
| `ghcr.io/chaeyoon-08/rag-mcp:latest` | python `3.11-slim` | 8000 | MCP 파일시스템 에이전트 |

> 같은 워크로드 내 컨테이너는 `localhost`로 상호 통신합니다. 별도 네트워크 설정은 필요하지 않습니다.

---

## 저장소 구조

```
├── webui/
│   ├── Dockerfile          한국어 로케일, Tesseract OCR, 기본 환경변수 내장
│   └── entrypoint.sh       시작 시 데이터 복구 → 백업 루프 → 서버 실행
├── ollama/
│   ├── Dockerfile          OLLAMA_MODELS 기본값 내장 (qwen3:8b, nomic-embed-text)
│   └── pull_models.sh      서버 기동 후 OLLAMA_MODELS 목록을 순서대로 pull
├── mcp/
│   ├── Dockerfile          Node.js 22 + mcpo 설치, config.json 내장
│   └── config.json         /workplace 경로를 MCP 파일시스템 도구로 노출
└── .github/workflows/
    ├── build-webui.yml     webui/ 변경 시 GHCR 자동 빌드
    ├── build-ollama.yml    ollama/ 변경 시 GHCR 자동 빌드
    └── build-mcp.yml       mcp/ 변경 시 GHCR 자동 빌드
```

---

## 워크로드 등록

### 목적 스펙

| 항목 | 값 |
|---|---|
| GPU | RTX 5070 Ti 이상 (VRAM 16GB 이상) |
| 최소 CUDA | 12.8.0 (Blackwell sm_120 완전 지원) |
| 공유 메모리 | 8GB |

> 기본 모델(qwen3:8b + nomic-embed-text) 동시 로드 시 약 5.5GB 사용. RTX 5090(32GB)에서는 qwen3:14b 이상으로 업그레이드 가능합니다.

---

### 클라우드 저장소 사전 준비

배포 전 gcube 클라우드 저장소 2개를 등록합니다.

| 저장소 역할 | 이름 예시 | 용도 |
|---|---|---|
| 공용 저장소 | `dropbox-storage` *(임의 지정)* | Open WebUI 데이터, 업로드 파일, MCP 파일시스템 |
| Qdrant 전용 저장소 | `dropbox-storage-qdrant` *(임의 지정)* | Qdrant 벡터 DB 전용 (데이터 충돌 방지) |

> **저장소 이름은 자유롭게 지정하십시오.** 이름은 gcube UI에서 선택하는 라벨이며 동작에 영향을 주지 않습니다. 중요한 것은 아래 각 컨테이너의 **마운트 경로**입니다.
>
> Qdrant는 내부적으로 `collections/` 디렉터리를 사용합니다. Open WebUI도 동일한 이름의 디렉터리를 사용하므로, 같은 저장소를 공유하면 데이터가 충돌할 수 있습니다. Qdrant는 반드시 별도 저장소를 사용하십시오.

---

### 컨테이너 1 — rag-webui

| 항목 | 값 |
|---|---|
| 저장소 유형 | GHCR |
| 이미지 | `ghcr.io/chaeyoon-08/rag-webui:latest` |
| 포트 | `8080` |

**환경변수**

| KEY | VALUE | 설명 |
|---|---|---|
| `WEBUI_SECRET_KEY` | *(직접 생성)* | JWT 암호화 키. 재배포 후 세션 유지를 위해 고정값이 필요합니다. `openssl rand -hex 32`로 생성하십시오. |

**클라우드 저장소 마운트**

| 클라우드 저장소 | 마운트 경로 |
|---|---|
| 공용 저장소 *(이름 임의)* | `/app/backend/data` |
| 공용 저장소 *(이름 임의)* | `/workplace/service_v1/uploads` |

---

### 컨테이너 2 — rag-ollama

| 항목 | 값 |
|---|---|
| 저장소 유형 | GHCR |
| 이미지 | `ghcr.io/chaeyoon-08/rag-ollama:latest` |
| 포트 | `11434` |

**환경변수** — 없음

> 기본 모델: `qwen3:8b,nomic-embed-text` (OLLAMA_MODELS 환경변수로 변경 가능)  
> VRAM 24GB 이상 환경에서는 `qwen3:14b,nomic-embed-text` 사용을 권장합니다.

**클라우드 저장소 마운트** — 없음

---

### 컨테이너 3 — qdrant

| 항목 | 값 |
|---|---|
| 저장소 유형 | Docker Hub |
| 이미지 | `qdrant/qdrant:v1.17.0` |
| 포트 | `6333` |

**환경변수** — 없음

**클라우드 저장소 마운트**

| 클라우드 저장소 | 마운트 경로 |
|---|---|
| Qdrant 전용 저장소 *(이름 임의)* | `/qdrant/storage` |

---

### 컨테이너 4 — rag-mcp

| 항목 | 값 |
|---|---|
| 저장소 유형 | GHCR |
| 이미지 | `ghcr.io/chaeyoon-08/rag-mcp:latest` |
| 포트 | `8000` |

**환경변수** — 없음

**클라우드 저장소 마운트**

| 클라우드 저장소 | 마운트 경로 |
|---|---|
| 공용 저장소 *(이름 임의)* | `/workplace` |

---

## MCP 연동

워크로드 배포 후 Open WebUI에서 MCP 에이전트를 등록합니다.

관리자 패널 → 설정 → 외부 도구 → 도구 서버 `+`

| 항목 | 값 |
|---|---|
| URL | `http://localhost:8000` |
| 이름 | `Files_Agent` |

등록 후 채팅 화면에서 `Files_Agent` 도구를 선택하면 `/workplace` 경로의 파일 조회, 읽기, 쓰기, 검색 기능을 사용할 수 있습니다.

---

## 배포 후 확인

모델 다운로드(qwen3:8b 약 5.2GB)가 완료되기 전까지 채팅 모델 선택이 비활성화됩니다.  
진행 상황은 rag-ollama 컨테이너 로그에서 확인할 수 있습니다.
