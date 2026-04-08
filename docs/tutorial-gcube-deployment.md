# RAG+MCP 스택 배포 튜토리얼

> **대상 독자:** gcube 플랫폼 사용 경험이 있는 운영자  
> **소요 시간:** 약 30분 (모델 다운로드 시간 제외)  
> **결과물:** Open WebUI + Ollama + Qdrant + MCP 파일 에이전트가 단일 워크로드로 동작하는 RAG 챗봇 서비스

---

## 목차

1. [사전 준비](#1-사전-준비)
2. [gcube 워크로드 생성](#2-gcube-워크로드-생성)
   - 2-1. [워크로드 기본 정보 입력](#2-1-워크로드-기본-정보-입력)
   - 2-2. [컨테이너 1 — rag-webui](#2-2-컨테이너-1--rag-webui)
   - 2-3. [컨테이너 2 — rag-ollama](#2-3-컨테이너-2--rag-ollama)
   - 2-4. [컨테이너 3 — qdrant](#2-4-컨테이너-3--qdrant)
   - 2-5. [컨테이너 4 — rag-mcp](#2-5-컨테이너-4--rag-mcp)
   - 2-6. [배포 실행](#2-6-배포-실행)
3. [배포 상태 확인](#3-배포-상태-확인)
4. [Open WebUI 초기 설정](#4-open-webui-초기-설정)
   - 4-1. [관리자 계정 생성](#4-1-관리자-계정-생성)
   - 4-2. [Ollama 연결 확인](#4-2-ollama-연결-확인)
   - 4-3. [MCP 도구 서버 등록](#4-3-mcp-도구-서버-등록)
5. [기능 확인](#5-기능-확인)
   - 5-1. [기본 채팅](#5-1-기본-채팅)
   - 5-2. [RAG 문서 업로드 및 질의](#5-2-rag-문서-업로드-및-질의)
   - 5-3. [MCP 파일 에이전트](#5-3-mcp-파일-에이전트)
6. [트러블슈팅](#6-트러블슈팅)

---

## 1. 사전 준비

배포 전 아래 항목을 준비합니다.

### 1-1. WEBUI_SECRET_KEY 생성

Open WebUI는 JWT 토큰 서명에 `WEBUI_SECRET_KEY`를 사용합니다. 이 값이 재배포마다 달라지면 기존 로그인 세션이 무효화되므로, 반드시 **고정값**을 생성하여 보관해야 합니다.

터미널에서 아래 명령으로 생성합니다.

```bash
openssl rand -hex 32
```

**출력 예시:**

```
a3f8c2e1d4b7a09f2e6c3d8b1a5f4e7c2d9b0a3f6e1c4d7b8a2f5e0c3d6b9a4
```

생성된 값을 메모장 등에 저장해 둡니다. 배포 후에도 동일한 값을 계속 사용해야 합니다.

### 1-2. 필요한 클라우드 저장소

gcube 내 **dropbox-storage** 유형의 클라우드 저장소가 사전에 생성되어 있어야 합니다.

| 저장소 이름 | 용도 |
|---|---|
| `dropbox-storage` | Open WebUI 데이터, 업로드 파일, Qdrant 벡터 DB, MCP 파일시스템 |

> **참고:** 동일한 저장소를 여러 경로에 마운트하여 사용합니다. 별도의 저장소를 컨테이너마다 생성할 필요가 없습니다.

### 1-3. GPU 요구사항

| 항목 | 최소 | 권장 |
|---|---|---|
| GPU 모델 | RTX 5070 Ti (VRAM 16GB) | RTX 5090 (VRAM 32GB) |
| 공유 메모리 | 8GB | 8GB |
| 기본 모델 | qwen3:8b + nomic-embed-text | qwen3:14b + nomic-embed-text |

> RTX 5090(32GB) 환경에서는 `OLLAMA_MODELS` 환경변수를 `qwen3:14b,nomic-embed-text`로 설정합니다.

---

## 2. gcube 워크로드 생성

gcube 콘솔에서 새 워크로드를 생성합니다. **컨테이너 4개를 단일 워크로드에 등록**합니다.

### 2-1. 워크로드 기본 정보 입력

| 항목 | 값 |
|---|---|
| 워크로드 이름 | `rag-mcp-stack` (자유롭게 지정) |
| GPU | RTX 5070 Ti 이상 선택 |
| 공유 메모리 | `8` GB |

> **CUDA 버전** 항목은 비워 두어도 됩니다. gcube가 선택한 GPU에 맞는 버전을 자동으로 설정합니다.

---

### 2-2. 컨테이너 1 — rag-webui

**이미지 정보**

| 항목 | 값 |
|---|---|
| 저장소 유형 | GHCR |
| 이미지 | `ghcr.io/chaeyoon-08/rag-webui:latest` |
| 포트 | `8080` |

**환경변수**

| KEY | VALUE |
|---|---|
| `WEBUI_SECRET_KEY` | [1-1단계](#1-1-webui_secret_key-생성)에서 생성한 값 |

> 이 환경변수 하나만 입력하면 됩니다. 나머지 설정(Ollama URL, Qdrant URL, OCR 등)은 이미지에 사전 구성되어 있습니다.

**클라우드 저장소 마운트**

| 클라우드 저장소 | 마운트 경로 |
|---|---|
| `dropbox-storage` | `/app/backend/data` |
| `dropbox-storage` | `/workplace/service_v1/uploads` |

---

### 2-3. 컨테이너 2 — rag-ollama

**이미지 정보**

| 항목 | 값 |
|---|---|
| 저장소 유형 | GHCR |
| 이미지 | `ghcr.io/chaeyoon-08/rag-ollama:latest` |
| 포트 | `11434` |

**환경변수**

기본값(qwen3:8b)을 사용하는 경우 환경변수 입력이 필요 없습니다.

RTX 5090(32GB) 환경에서 qwen3:14b를 사용하려면 아래를 추가합니다.

| KEY | VALUE |
|---|---|
| `OLLAMA_MODELS` | `qwen3:14b,nomic-embed-text` |

**클라우드 저장소 마운트** — 없음

---

### 2-4. 컨테이너 3 — qdrant

**이미지 정보**

| 항목 | 값 |
|---|---|
| 저장소 유형 | Docker Hub |
| 이미지 | `qdrant/qdrant:v1.17.0` |
| 포트 | `6333` |

**환경변수** — 없음

**클라우드 저장소 마운트**

| 클라우드 저장소 | 마운트 경로 |
|---|---|
| `dropbox-storage` | `/qdrant/storage` |

---

### 2-5. 컨테이너 4 — rag-mcp

**이미지 정보**

| 항목 | 값 |
|---|---|
| 저장소 유형 | GHCR |
| 이미지 | `ghcr.io/chaeyoon-08/rag-mcp:latest` |
| 포트 | `8000` |

**환경변수** — 없음

**클라우드 저장소 마운트**

| 클라우드 저장소 | 마운트 경로 |
|---|---|
| `dropbox-storage` | `/workplace` |

---

### 2-6. 배포 실행

4개 컨테이너 설정이 완료되면 **배포** 버튼을 클릭합니다.

> **이미지 경로 표시 관련:** 유효성 검사 후 `ghcr.io/` 등 레지스트리 prefix가 UI에서 생략되어 표시될 수 있습니다. 내부적으로는 전체 경로가 정상 사용되므로 무시해도 됩니다.

---

## 3. 배포 상태 확인

### 3-1. 워크로드 상태

gcube 워크로드 목록에서 상태가 **Running**으로 전환될 때까지 대기합니다. 일반적으로 이미지 풀 완료 후 1~3분 내에 전환됩니다.

### 3-2. 컨테이너별 로그 확인

각 컨테이너 로그에서 아래 메시지를 확인합니다.

**rag-ollama 로그 — 정상 기동 시**

```
[ollama] Waiting for server...
[ollama] Server ready.
[ollama] Pulling model: qwen3:14b
pulling manifest...
pulling ...  ████████████  100%
[ollama] Pulling model: nomic-embed-text
...
[ollama] All models pulled.
```

> 모델 다운로드 시간: qwen3:14b 약 9GB → 네트워크 환경에 따라 5~15분 소요됩니다. 다운로드가 완료되기 전까지 Open WebUI의 모델 선택 목록이 비어 있는 것은 정상입니다.

**rag-webui 로그 — 정상 기동 시**

```
INFO  [open_webui.main] Application startup complete.
Uvicorn running on http://0.0.0.0:8080
```

**qdrant 로그 — 정상 기동 시**

```
Qdrant gRPC listening on 6334
REST API listening on 6333
```

> `FUSE filesystems may cause data corruption` 경고 메시지가 출력될 수 있습니다. gcube dropbox-storage가 FUSE 기반이기 때문에 발생하는 경고이며, Qdrant는 정상 동작합니다.

**rag-mcp 로그 — 정상 기동 시**

```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
```

### 3-3. 서비스 URL 접속 확인

gcube 워크로드 상세 페이지에서 **서비스 URL**을 클릭합니다. Open WebUI 로그인 화면이 표시되면 정상입니다.

---

## 4. Open WebUI 초기 설정

### 4-1. 관리자 계정 생성

Open WebUI에 처음 접속하면 계정 생성 화면이 표시됩니다.

1. **이름**, **이메일**, **비밀번호**를 입력합니다.
2. **계정 생성** 버튼을 클릭합니다.
3. 최초 생성된 계정이 자동으로 **관리자(Admin)** 권한을 갖습니다.

> 이 계정 정보는 `/app/backend/data`(dropbox-storage)에 저장되므로, 워크로드를 재배포해도 유지됩니다.

### 4-2. Ollama 연결 확인

1. 우측 상단 계정 아이콘 → **관리자 패널** 클릭
2. **설정** → **연결** 탭 이동
3. **Ollama API** 항목에서 `http://localhost:11434`가 표시되고 초록색 체크 아이콘이 있으면 정상입니다.
4. 연결이 되지 않는 경우 → rag-ollama 컨테이너 로그에서 모델 다운로드가 완료되었는지 확인합니다.

### 4-3. MCP 도구 서버 등록

1. **관리자 패널** → **설정** → **외부 도구** 탭 이동
2. **도구 서버** 섹션에서 `+` 버튼 클릭
3. 아래 값을 입력합니다.

| 항목 | 값 |
|---|---|
| URL | `http://localhost:8000` |
| 이름 | `Files_Agent` |

4. **저장** 클릭 후 초록색 체크 아이콘이 표시되면 연결 성공입니다.

---

## 5. 기능 확인

### 5-1. 기본 채팅

1. 좌측 메뉴에서 **새 채팅** 클릭
2. 상단 모델 선택 드롭다운에서 `qwen3:14b` (또는 `qwen3:8b`) 선택
3. 입력창에 아래 질문을 입력하고 응답을 확인합니다.

```
안녕하세요. 오늘 날씨에 대해 짧게 이야기해 주세요.
```

응답이 정상적으로 반환되면 Ollama 연동이 완료된 것입니다.

---

### 5-2. RAG 문서 업로드 및 질의

#### Knowledge Base 생성

1. 좌측 메뉴 **Workspace** → **Knowledge** 이동
2. `+` 버튼 → **Create Knowledge Base** 클릭
3. 이름 입력 (예: `테스트 문서`) 후 **생성**

#### 문서 업로드

1. 생성된 Knowledge Base 클릭
2. **Upload Files** 버튼 클릭 → PDF, DOCX, TXT 등 파일 선택
3. 업로드 완료 후 파일 목록에 항목이 표시되면 인덱싱 성공입니다.

> 테스트용 문서가 없는 경우 이 레포지토리의 `docs/test_document.pdf`를 사용할 수 있습니다.

#### RAG 채팅

1. **새 채팅** 클릭
2. 입력창 왼쪽 `+` 버튼 → **Knowledge Base** → 방금 생성한 Knowledge Base 선택
3. 문서 내용에 관한 질문을 입력합니다.

**테스트 질문 예시 (test_document.pdf 사용 시):**

| 질문 | 기대 답변 요소 |
|---|---|
| NX-E720의 VRAM 용량은? | 96GB |
| 재택근무 신청 마감일이 언제야? | 2025년 7월 18일 (금) 18:00 |
| 보안팀장(CISO) 이메일 주소는? | minjun.choi@nextech.example |
| 2025 Q1 매출은 얼마야? | USD 63.4억 |
| R-002 리스크 대응 현황은? | 취약점 3건 패치 완료, Security Upgrade v3 진행 중 |

응답에 문서 내용이 포함되고 출처(소스 파일명)가 표시되면 RAG가 정상 동작하는 것입니다.

---

### 5-3. MCP 파일 에이전트

MCP 에이전트를 통해 dropbox-storage(`/workplace`)에 마운트된 파일을 조회·읽기·쓰기할 수 있습니다.

#### 에이전트 활성화

1. **새 채팅** 클릭
2. 입력창 하단 도구 아이콘 클릭 → **Files_Agent** 체크박스 활성화

#### 기능 확인 질문

| 목적 | 질문 예시 |
|---|---|
| 파일 목록 조회 | `/workplace 경로에 어떤 파일이 있어?` |
| 파일 읽기 | `/workplace/service_v1/uploads 폴더 내 파일 목록 보여줘` |
| 파일 생성 | `/workplace에 hello.txt 파일을 만들고 "테스트 성공"이라고 써줘` |

응답에 파일 목록이나 내용이 반환되면 MCP 연동이 정상입니다.

---

## 6. 트러블슈팅

### 서비스 URL 접속 시 화면이 열리지 않는 경우

- rag-webui 컨테이너 로그에서 `Application startup complete` 메시지를 확인합니다.
- 로그에 에러가 없으면 1~2분 더 대기 후 재시도합니다.

### 모델 선택 목록이 비어 있는 경우

- rag-ollama 로그에서 `[ollama] All models pulled.` 메시지를 확인합니다.
- 메시지가 없으면 모델 다운로드가 진행 중입니다. 완료될 때까지 대기합니다.
- 다운로드 중 `Error` 로그가 있으면 워크로드를 재시작합니다.

### Ollama 연결 오류 (빨간 X 아이콘)

- rag-ollama 컨테이너가 Running 상태인지 확인합니다.
- rag-ollama 로그에서 서버 기동 오류 여부를 확인합니다.
- 문제가 없으면 Open WebUI에서 **연결 재시도** 버튼을 클릭합니다.

### MCP 도구 서버 연결 오류

- rag-mcp 컨테이너가 Running 상태인지 확인합니다.
- rag-mcp 로그에서 `Application startup complete` 메시지를 확인합니다.
- `/workplace` 마운트 경로가 올바르게 설정되었는지 확인합니다.

### Qdrant `FUSE filesystem` 경고

- 정상 동작하는 경고입니다. 무시해도 됩니다.
- 경고를 억제하려면 rag-qdrant 컨테이너에 아래 환경변수를 추가합니다.
  - KEY: `QDRANT__STORAGE__SKIP_FS_CHECK` / VALUE: `true`

### 재배포 후 로그인 세션이 초기화되는 경우

- `WEBUI_SECRET_KEY` 값이 이전 배포와 동일한지 확인합니다.
- 다른 값을 입력한 경우 기존 JWT 토큰이 무효화됩니다. 동일한 값으로 재배포합니다.

---

*문서 버전: 1.0 / 최종 수정: 2025-07-01*
