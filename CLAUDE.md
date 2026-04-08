# rag-mcp-stack 프로젝트 컨텍스트

## 프로젝트 개요

Open WebUI + Ollama + Qdrant + MCP 기반 RAG 챗봇 스택.
gcube 클라우드 GPU 플랫폼에 4개 컨테이너를 단일 워크로드로 배포.

## 배포 환경

- 플랫폼: gcube (Kubernetes 기반, FUSE Dropbox 클라우드 스토리지)
- GPU: RTX 5090 (32GB VRAM)
- 컨테이너 간 통신: 동일 워크로드 내 `localhost` 공유
- GHCR 이미지 자동 빌드: `.github/workflows/` 아래 각 컴포넌트별 workflow

## 컨테이너 구성

| 컨테이너 | 이미지 | 포트 |
|---|---|---|
| rag-webui | `ghcr.io/chaeyoon-08/rag-webui:latest` | 8080 |
| rag-ollama | `ghcr.io/chaeyoon-08/rag-ollama:latest` | 11434 |
| qdrant | `ghcr.io/chaeyoon-08/rag-qdrant:latest` | 6333 |
| rag-mcp | `ghcr.io/chaeyoon-08/rag-mcp:latest` | 8000 |

## 핵심 아키텍처 결정사항

### 클라우드 저장소 (Dropbox/FUSE) 마운트 정책

gcube의 Dropbox는 FUSE 기반이며 다음 제약이 있음:

| 컨테이너 | 마운트 경로 | 저장소 | 이유 |
|---|---|---|---|
| rag-webui | `/app/backend/data` | 공용 저장소 | DB, 설정 영속화 |
| rag-webui | `/workplace/service_v1/uploads` | 공용 저장소 | 업로드 파일 |
| rag-mcp | `/workplace` | 공용 저장소 | MCP 파일시스템 노출 |
| qdrant | `/snapshots` | Qdrant 전용 저장소 | 스냅샷 파일 저장 (FUSE I/O 오류 우회) |

> **Qdrant 스토리지는 FUSE에 직접 마운트하지 않는다.**
> Qdrant v1.17.0은 FUSE 감지 시 경고를 출력하고, 벡터 스토리지 디렉토리 생성 시 `Input/output error (os error 5)`로 실패한다.
> 대신 커스텀 이미지(`rag-qdrant`)에서 10분 주기로 스냅샷을 생성해 `/snapshots`(Dropbox 마운트)에 저장한다.
> 재배포 시 `snapshot.sh`가 `/snapshots`의 `.snapshot` 파일로 컬렉션을 자동 복원한다.
> v1.17.0에서 스냅샷 생성 중 쓰기 블로킹 락이 제거되어 RAG 동작에 영향 없음 (릴리즈 노트 #8072).

### SQLite on FUSE 문제 (rag-webui)

Open WebUI SQLite DB가 FUSE에 마운트되어 있어 다음 현상이 발생:

1. **파일 업로드 실패**: `db.refresh()` 후 `InvalidRequestError` → `NoneType.model_dump()` AttributeError
   - 수정: `webui/patch_files.py` — `db.commit()` 직후 `db.refresh()` 실패 시 `db.expire() + db.get()` fallback
   - Dockerfile에서 `COPY patch_files.py` + `RUN python3 /tmp/patch_files.py`로 적용
2. **페이지 렌더링 지연**: 모든 DB 쿼리가 FUSE 레이턴시를 통과 → 누적 수초 지연. 해결책 없음(옵션 B: DB 로컬 분리는 재배포 시 데이터 초기화 문제로 채택 안 함)

### 파일 업로드 패치 적용 방식

- 이전 실패: Dockerfile heredoc 방식 → shell 이스케이프 문제로 들여쓰기 깨짐 → `IndentationError` → 컨테이너 부팅 불가
- 현재 방식: `webui/patch_files.py` 별도 파일 분리, `COPY + RUN` 적용
- 패턴: `db.commit()` + `db.refresh(result)` + `if result:` 3줄 컨텍스트로 유일하게 특정
- 보호 로직: 패턴 미매칭 또는 `ast.parse()` 실패 시 `sys.exit(1)` → 빌드 실패

## 알려진 문제 및 현황

### 해결됨
- [x] Open WebUI v0.6.5 → v0.8.6 업그레이드 (admin settings 500 오류 해결)
- [x] Qdrant 전용 저장소 분리 (`collections/` 디렉토리 충돌 해결)
- [x] `DEFAULT_MODELS` 환경변수 제거 (OLLAMA_MODELS와 불일치 문제)
- [x] 파일 업로드 `db.refresh()` 실패 패치 적용

### 미해결
- [ ] **gcube qdrant 컨테이너 교체**: 이미지를 `rag-qdrant:latest`로 변경, 마운트를 `/qdrant/storage` → `/snapshots`로 변경 (수동 작업)
- [ ] 페이지 렌더링 지연 (FUSE SQLite 레이턴시 누적, 근본 해결 미채택)
- [ ] Ollama 모델 재배포마다 재다운로드 (`/root/.ollama` 마운트 없음)

## 환경변수 주의사항

- `WEBUI_SECRET_KEY`: gcube 환경변수에서 직접 설정 필수. 미설정 시 재배포마다 세션 초기화.
- `OLLAMA_MODELS`: Dockerfile 기본값 `qwen3:8b,nomic-embed-text`. 변경 시 환경변수 오버라이드.

## 커밋/작업 규칙

- 커밋 메시지는 한국어로 작성
- git push 전 반드시 사용자에게 구두로 허락을 받을 것
- 코드 변경 전 반드시 실제 소스(GitHub raw 등)를 확인하고 패턴 검증 후 적용
