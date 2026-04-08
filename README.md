# rag-mcp-stack

Open WebUI + Ollama + Qdrant + MCP 기반 RAG 챗봇 및 파일 에이전트 스택입니다.
단일 워크로드에 4개 컨테이너를 등록하고 `WEBUI_SECRET_KEY`만 설정하면 배포가 완료됩니다.

배포 방법 및 테스트 절차는 `docs/TUTORIAL.md`를 참고하십시오.

---

## 이미지 목록

| 이미지 | 베이스 | 포트 | 역할 |
|---|---|---|---|
| `ghcr.io/chaeyoon-08/rag-webui:latest` | open-webui `v0.8.6` | 8080 | 사용자 UI (Open WebUI) |
| `ghcr.io/chaeyoon-08/rag-ollama:latest` | ollama `v0.20.2` | 11434 | LLM 및 임베딩 추론 서버 |
| `ghcr.io/chaeyoon-08/rag-qdrant:latest` | qdrant `v1.17.0` | 6333 | 벡터 데이터베이스 (스냅샷 자동 저장/복원) |
| `ghcr.io/chaeyoon-08/rag-mcp:latest` | python `3.11-slim` | 8000 | MCP 파일시스템 에이전트 |

> 같은 워크로드 내 컨테이너는 `localhost`로 상호 통신합니다. 별도 네트워크 설정은 필요하지 않습니다.

---

## 저장소 구조

```
├── webui/
│   ├── Dockerfile          한국어 로케일, Tesseract OCR, 기본 환경변수 내장
│   ├── entrypoint.sh       시작 시 DB 복원 → 10분 주기 DB 백업 → 서버 실행
│   └── patch_files.py      FUSE SQLite db.refresh() 실패 패치 (빌드 시 적용)
├── ollama/
│   ├── Dockerfile          OLLAMA_MODELS 기본값 내장 (qwen3:8b, nomic-embed-text)
│   └── pull_models.sh      서버 기동 후 OLLAMA_MODELS 목록을 순서대로 pull
├── qdrant/
│   ├── Dockerfile          qdrant v1.17.0 베이스, curl 설치, snapshot.sh 내장
│   └── snapshot.sh         시작 시 스냅샷 복원 → 10분 주기 스냅샷 저장
├── mcp/
│   ├── Dockerfile          Node.js 22 + mcpo 설치, config.json 내장
│   └── config.json         /workplace 경로를 MCP 파일시스템 도구로 노출
├── docs/
│   ├── README.md           이 문서
│   ├── TUTORIAL.md         gcube 배포 및 기능 테스트 튜토리얼
│   └── test_document.pdf   RAG 테스트용 가상 문서
└── .github/workflows/
    ├── build-webui.yml     webui/ 변경 시 GHCR 자동 빌드
    ├── build-ollama.yml    ollama/ 변경 시 GHCR 자동 빌드
    ├── build-qdrant.yml    qdrant/ 변경 시 GHCR 자동 빌드
    └── build-mcp.yml       mcp/ 변경 시 GHCR 자동 빌드
```

---

## 목적 스펙

| 항목 | 값 |
|---|---|
| GPU | RTX 5070 Ti 이상 (VRAM 16GB 이상) |
| 최소 CUDA | 12.8.0 (Blackwell sm_120 완전 지원) |
| 공유 메모리 | 8GB |

> 기본 모델(qwen3:8b + nomic-embed-text) 동시 로드 시 약 5.5GB 사용.
> RTX 5090(32GB)에서는 `OLLAMA_MODELS=qwen3:14b,nomic-embed-text`로 업그레이드 가능합니다.

---

## 주요 설계 결정

### Qdrant 스냅샷 기반 영속성

gcube의 클라우드 저장소는 FUSE 기반입니다. Qdrant는 FUSE 경로에 스토리지를 직접 마운트하면 `Input/output error`로 실패합니다. 이를 우회하기 위해 커스텀 이미지(`rag-qdrant`)에서 아래 방식을 사용합니다.

- Qdrant 스토리지는 컨테이너 **로컬 디스크**에 유지
- 10분 주기로 스냅샷(`.snapshot` 파일)을 생성해 `/snapshots`(Dropbox 마운트)에 저장
- 재배포 시 `snapshot.sh`가 `/snapshots`의 스냅샷 파일로 컬렉션 자동 복원
- v1.17.0에서 스냅샷 생성 중 쓰기 블로킹이 제거되어 RAG 동작에 영향 없음

> 재배포 시점과 마지막 스냅샷 사이(최대 10분)에 추가된 파일은 재업로드가 필요합니다.

### Open WebUI DB 백업 기반 영속성

gcube FUSE 저장소에 SQLite DB를 직접 마운트하면 파일 락 미지원으로 DB가 손상됩니다(`database disk image is malformed`). 이를 우회하기 위해 아래 방식을 사용합니다.

- `/app/backend/data`(DB 경로)는 컨테이너 **로컬 디스크**에 유지 (마운트 없음)
- 10분 주기로 Python `sqlite3.backup()` API를 사용해 `/db_backup`(Dropbox 마운트)에 저장
- 재배포 시 `entrypoint.sh`가 `/db_backup/webui.db`로 자동 복원
- `sqlite3.backup()`은 DB 사용 중에도 안전하게 동작 (서비스 중단 없음)

> 재배포 시점과 마지막 백업 사이(최대 10분)에 생성된 채팅/설정은 유실될 수 있습니다.
