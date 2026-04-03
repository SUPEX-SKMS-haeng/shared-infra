# 개발자 가이드

Agent Template Apps 프로젝트의 개발 환경 셋업부터 일상적인 개발 플로우까지 안내합니다.

---

## 1. 전체 아키텍처

```
agent-template-apps (GitHub Organization)
├── shared-infra          ← 이 레포. 공통 인프라, 룰, 설정
├── backend-auth          ← 인증/JWT/사용자관리       :8001
├── backend-base          ← 기본 API/조직관리         :8002
├── backend-chat          ← 채팅/LLM 스트리밍         :8003
├── backend-llm-gateway   ← LLM 라우팅/프롬프트관리   :8080
├── backend-mcp           ← MCP 도구/벡터DB           :8084
└── frontend              ← 프론트엔드 (admin :3001 / chat :3000)
```

모든 앱은 `infra/` 서브모듈로 shared-infra를 참조합니다.
개발 표준, Claude Code 커맨드, 코드 포맷 설정 등이 중앙에서 관리됩니다.

---

## 2. 최초 셋업 (신규 개발자)

### 2.1 사전 요구사항

| 도구        | 버전    | 용도                                                      |
| ----------- | ------- | --------------------------------------------------------- |
| Git         | 최신    | 소스 관리                                                 |
| Python      | >= 3.12 | 백엔드                                                    |
| uv          | 최신    | Python 패키지 관리                                        |
| Node.js     | >= 20   | 프론트엔드                                                |
| pnpm        | 최신    | Node 패키지 관리                                          |
| Docker      | 최신    | 로컬 DB (PostgreSQL, Redis)                               |
| Claude Code | 최신    | AI 기반 개발 (`npm install -g @anthropic-ai/claude-code`) |

### 2.2 자동 셋업 (권장)

```bash
# 1. shared-infra 클론
git clone https://github.com/agent-template-apps/shared-infra.git
cd shared-infra

# 2. developer-setup.sh 실행 (최초 1회)
./scripts/developer-setup.sh
```

스크립트가 대화형으로 안내합니다:

```
╔══════════════════════════════════════════╗
║   Agent Template Apps — 개발환경 셋업    ║
╚══════════════════════════════════════════╝

[0] 전체 (7개 모두)
[1] backend-auth       [2] backend-base       [3] backend-chat
[4] backend-llm-gateway [5] backend-mcp
[6] frontend-chat      [7] frontend-admin

선택 (쉼표로 구분, 예: 1,3,6): _
```

스크립트가 자동으로 하는 일:

1. 사전 요구사항 체크 (git, python, uv, node, pnpm, docker)
2. 워크스페이스 디렉토리 지정
3. 선택한 앱 레포 클론 (`git clone --recurse-submodules`)
4. 설정 파일 배포 (`.vscode/`, `ruff.toml`, `.pre-commit-config.yaml` 등)
5. 로컬 DB 기동 (PostgreSQL + Redis, Docker)
6. 백엔드: `uv sync` (가상환경 + 의존성) → `.env` 생성 → `pre-commit` 설치
7. 프론트엔드: `pnpm install` → 빌드 테스트
8. 완료 요약 및 실행 명령어 안내

빠른 옵션:

```bash
./scripts/developer-setup.sh --all        # 전체 앱
./scripts/developer-setup.sh --backend    # 백엔드만
./scripts/developer-setup.sh --frontend   # 프론트엔드만
```

### 2.3 셋업 결과 (앱 레포 구조)

셋업 후 각 앱 레포의 구조:

```
backend-auth/
├── CLAUDE.md                    ← 앱별 개발 규칙
├── ruff.toml                    ← Python 린트/포맷 (shared-infra에서 복사)
├── .editorconfig                ← 에디터 공통 설정
├── .pre-commit-config.yaml      ← 커밋 전 자동 검사
├── .vscode/
│   ├── settings.json            ← 저장 시 자동 포맷
│   └── extensions.json          ← 추천 확장 목록
├── .claude/
│   ├── commands/                ← 슬래시 커맨드 (/start-task 등)
│   └── agents/                  ← 서브에이전트 (@code-reviewer 등)
├── .github/
│   ├── ISSUE_TEMPLATE/          ← 이슈 템플릿
│   └── workflows/
│       ├── llm-review.yml       ← LLM PR 자동 리뷰
│       └── sync-notion.yml     ← Notion 동기화
├── .env                         ← 환경 변수 (.env.example에서 복사)
├── infra/                       ← shared-infra 서브모듈
└── app/                         ← 앱 소스 코드
```

---

## 3. 매일 개발 시작

### 3.1 서버 시작 (start-dev.sh)

```bash
cd ~/Workspace/GitHub/shared-infra

# 전체 기동 (DB + 백엔드 5개 + 프론트 1개)
./scripts/start-dev.sh --all

# 백엔드만
./scripts/start-dev.sh --backend

# 원하는 앱만
./scripts/start-dev.sh 1,3,6         # auth + chat + frontend

# 상태 확인
./scripts/start-dev.sh --status

# 전체 중지
./scripts/start-dev.sh --stop
```

start-dev.sh는 다음을 자동으로 합니다:

- Docker로 PostgreSQL(:5432) + Redis(:6379) 기동 (이미 떠있으면 건너뜀)
- 선택한 앱을 백그라운드로 실행
- 각 앱의 로그는 `.dev-logs/` 디렉토리에 저장

### 3.2 로그 확인

```bash
# 특정 앱 로그 실시간
tail -f shared-infra/.dev-logs/backend-auth.log

# 전체 로그
tail -f shared-infra/.dev-logs/*.log
```

### 3.3 DB 관리

```bash
cd shared-infra

# DB 시작/중지
docker compose -f docker-compose.dev.yml up -d
docker compose -f docker-compose.dev.yml down

# DB 초기화 (데이터 완전 삭제)
docker compose -f docker-compose.dev.yml down -v

# DB 접속
docker exec -it dev-postgres psql -U user -d dev
```

접속 정보 (`.env.example` 기본값):

```
DB_HOST=127.0.0.1  DB_PORT=5432  DB_NAME=dev
DB_USER=user       DB_PASSWORD=password
REDIS_HOST=127.0.0.1  REDIS_PORT=6379
```

---

## 4. 개발 워크플로우 (개발자)

### 4.1 태스크 시작

PL이 생성한 GitHub Issue를 받으면:

```bash
cd backend-auth
claude                    # Claude Code 시작
> /start-task 42          # Issue #42 기반 작업 시작
```

`/start-task`가 하는 일:

- GitHub Issue #42 내용 확인
- 작업 브랜치 생성 (`feat/auth/42-add-oauth`)
- 이슈에 작업 시작 코멘트 추가

### 4.2 개발 진행

Claude Code 또는 VS Code로 개발합니다 (혼용 가능).

Claude Code로 작업:

```
> 이슈 내용 기반으로 OAuth2 구글 로그인 엔드포인트를 구현해줘.
> @code-reviewer 지금까지 변경된 코드 리뷰해줘
> @test-runner 테스트 실행하고 결과 알려줘
```

VS Code로 작업:

- 저장(Ctrl+S) 시 자동 포맷 (Ruff/Prettier)
- 코드 작성 → 저장 → 자동으로 import 정렬, 따옴표 통일, 줄 길이 조정

### 4.3 태스크 완료

```
> /finish-task
```

`/finish-task`는 6단계로 진행됩니다:

**① 변경사항 분석** — `git diff`로 어떤 파일이 어떻게 바뀌었는지 파악

**② 린트 & 테스트** — 백엔드: `uv run ruff check .` / 프론트엔드: `pnpm lint`

**③ 커밋 메시지 자동 생성** — 변경사항을 분석하여 Conventional Commits 형식으로 자동 생성

```
feat(oauth): Google OAuth2 로그인 구현

- /api/v1/auth/google 엔드포인트 추가
- GoogleOAuthService 서비스 레이어 구현
- JWT 토큰 발급 로직 연동

Refs #42
```

→ **사용자 확인**: 생성된 메시지를 보여주고, 수정이 필요하면 반영합니다. "확인" 또는 "ㅇㅇ" 등 승인하면 그대로 진행.

**④ 커밋 & Push** — `git add -A` → 확인된 메시지로 커밋 → `git push -u origin {브랜치}`

**⑤ PR 메시지 자동 생성** — 커밋 히스토리와 변경 파일 기반으로 PR 제목/본문 자동 생성

```
제목: Google OAuth2 로그인 구현

## 개요
사용자가 Google 계정으로 로그인할 수 있는 OAuth2 인증 엔드포인트를 추가합니다.

## 변경 내용
- /api/v1/auth/google 엔드포인트 추가
- GoogleOAuthService 서비스 레이어 구현
- JWT 토큰 발급 로직 연동

## 테스트
- [ ] Google OAuth 로그인 정상 동작
- [ ] JWT 토큰 발급 확인

Closes #42
```

→ **사용자 확인**: 생성된 PR 메시지를 보여주고, 수정이 필요하면 반영합니다.

**⑥ PR 생성 & 이슈 업데이트** — `gh pr create`로 PR 생성 → 이슈에 "✅ PR 생성 완료" 코멘트 추가

커밋 메시지 규칙: `{type}({scope}): {한글 요약}` (50자 이내). type은 feat/fix/refactor/chore/docs/test/style 중 선택.

### 4.4 PR 리뷰 (2단계)

PR이 생성되면 자동으로:

1. **1단계: LLM 자동 리뷰** — `llm-review.yml`이 트리거되어 기능 충족, 에러 처리, 보안, 코드 품질 등을 자동 검사. PR에 리뷰 코멘트가 달립니다.
2. **2단계: PL 최종 리뷰** — LLM 리뷰를 참고하여 PL이 Approve/Request Changes.

---

## 5. PL 워크플로우

### 5.1 기능을 태스크로 분해

```
> @task-planner 사용자가 소셜 로그인(Google, Kakao)으로
  회원가입/로그인할 수 있는 기능을 구현해야 해.
  backend-auth와 frontend에 모두 변경이 필요해.
```

### 5.2 태스크 생성

```
> /create-task 사용자가 Google OAuth2로 로그인할 수 있도록
  backend-auth에 /api/v1/auth/google 엔드포인트 추가
```

### 5.3 인프라 업데이트

```
> /update-infra                # 전체 앱의 shared-infra 서브모듈 업데이트
```

### 5.4 문서 기반 태스크 생성

```
> /create-tasks-from-doc       # 개발상세정의서 기반 태스크 자동 생성
```

### 5.5 Notion 동기화

```
> /sync-notion              # 수동 동기화
```

GitHub Issues 상태 변경 시 Notion에 자동 반영됩니다 (`sync-notion.yml`).

---

## 6. 코드 포맷 & 린트

코드 포맷은 3단계로 강제됩니다. 개발자가 별도로 신경 쓸 필요 없습니다.

### 6.1 1단계: 코딩 중 (VS Code 자동 포맷)

VS Code로 프로젝트를 열면 "추천 확장을 설치하시겠습니까?" 알림이 뜹니다.

| 역할   | 백엔드                                     | 프론트엔드                          |
| ------ | ------------------------------------------ | ----------------------------------- |
| 포맷터 | Ruff (`charliermarsh.ruff`)                | Prettier (`esbenp.prettier-vscode`) |
| 린터   | Ruff (내장)                                | ESLint (`dbaeumer.vscode-eslint`)   |
| 에디터 | EditorConfig (`editorconfig.editorconfig`) | 동일                                |

확장 설치 후 파일 저장(Ctrl+S) 시 자동 포맷됩니다.

### 6.2 2단계: 커밋 직전 (pre-commit hook)

`git commit` 실행 시 자동으로 린트/포맷 검사:

- 백엔드: Ruff 린트 + 포맷 + import 정렬
- 프론트엔드: Prettier 포맷
- 공통: trailing whitespace, EOF, YAML/JSON 검사, 대용량 파일 차단

포맷이 안 맞으면 자동 수정 후 커밋 중단 → `git add` 후 다시 `git commit`.

### 6.3 3단계: PR 이후 (LLM 리뷰)

LLM PR 리뷰가 코드 품질/포맷을 추가 검사합니다 (1~2단계에서 이미 포맷은 맞춰진 상태).

### 6.4 설정 파일 위치

| 파일            | 원본 (shared-infra)                 | 앱 레포 (복사본)          |
| --------------- | ----------------------------------- | ------------------------- |
| `ruff.toml`     | `configs/ruff.toml`                 | `./ruff.toml`             |
| `.prettierrc`   | `configs/.prettierrc`               | `./.prettierrc`           |
| `.editorconfig` | `configs/.editorconfig`             | `./.editorconfig`         |
| VS Code 설정    | `configs/vscode-*.json`             | `.vscode/settings.json`   |
| pre-commit      | `configs/.pre-commit-config-*.yaml` | `.pre-commit-config.yaml` |

설정을 수정하려면 shared-infra의 `configs/`에서 원본을 수정 → `sync-all-repos.sh`로 전체 반영.

---

## 7. 개발 표준 문서

실제 코드에서 추출한 상세 개발 표준:

- [백엔드 개발 표준](standards/backend-standards.md) — 에러 처리, API 응답 형식, 보안/인증, DB 패턴, 로깅 등
- [프론트엔드 개발 표준](standards/frontend-standards.md) — API 호출 패턴, 인증 흐름, 컴포넌트 규칙, 상태관리 등
- [워크플로우 커스터마이징 가이드](workflow-customization-guide.md) — 템플릿을 복사한 팀이 규칙/설정을 자기 프로젝트에 맞게 수정하는 방법

이 문서들은 CLAUDE.md에서 `@infra/docs/standards/` 경로로 참조됩니다.
Claude Code가 코드를 생성할 때 이 표준을 자동으로 따릅니다.

---

## 8. shared-infra 업데이트 반영

PL이 shared-infra에서 룰이나 설정을 변경했을 때:

```bash
# PL이 shared-infra 변경 후 push
cd shared-infra
git add -A && git commit -m "chore: update ruff rules" && git push

# 전체 앱에 반영
./scripts/sync-all-repos.sh              # 확인만
./scripts/sync-all-repos.sh --commit     # 반영 + 자동 커밋
./scripts/sync-all-repos.sh --push       # 반영 + 커밋 + push
```

개별 앱에서 수동으로 반영:

```bash
cd backend-auth
git submodule update --remote infra
./infra/scripts/setup-repo.sh
```

---

## 9. Claude Code 사용 팁

### 9.1 컨텍스트 관리

| 상황               | 명령                |
| ------------------ | ------------------- |
| 작업 전환 시 리셋  | `/clear`            |
| 이전 세션 이어서   | `claude --continue` |
| 세션 목록에서 선택 | `claude --resume`   |

### 9.2 작업 패턴별 권장 방법

| 상황                 | 방법                                     |
| -------------------- | ---------------------------------------- |
| 단순 수정            | Claude에 바로 요청                       |
| 새 엔드포인트/페이지 | Plan Mode (Shift+Tab) → 계획 확인 → 구현 |
| 복잡한 기능          | `@task-planner`로 분해 → 단위별 구현     |
| 버그 수정            | 에러 로그 붙여넣기 → Claude 분석/수정    |
| 코드 리뷰            | `@code-reviewer`                         |
| 테스트 실행          | `@test-runner`                           |

### 9.3 CLAUDE.md 구조

```
shared-infra/CLAUDE.md          ← 전체 공통 (에러처리, 보안, API 형식 등)
  ↑ 참조
backend-auth/CLAUDE.md          ← 앱별 고유 (JWT, Redis, bcrypt 등)
```

Claude Code는 프로젝트 루트의 `CLAUDE.md`와 `infra/CLAUDE.md`를 모두 자동으로 읽습니다.

---

## 10. 스크립트 요약

| 스크립트             | 언제                 | 누가        | 하는 일                               |
| -------------------- | -------------------- | ----------- | ------------------------------------- |
| `developer-setup.sh` | 최초 1회             | 새 개발자   | 클론 → DB → venv → 의존성 → 실행 확인 |
| `start-dev.sh`       | 매일                 | 모든 개발자 | DB + 앱 기동/중지/상태 확인           |
| `sync-all-repos.sh`  | shared-infra 변경 시 | PL          | 전체 앱 설정 재배포                   |
| `setup-repo.sh`      | 서브모듈 연결 후     | 개발자      | 단일 앱 설정 배포                     |
| `setup-all-repos.sh` | 서브모듈 연결 후     | PL          | 전체 앱 설정 배포                     |
| `update-all-repos.sh`| shared-infra 변경 시 | PL          | 전체 앱의 서브모듈 참조 업데이트      |

---

## 11. Notion 연동

### 11.1 Notion Integration 생성

1. https://www.notion.so/my-integrations → "New integration"
2. 이름: `agent-template-github-sync`
3. Capabilities: Read/Update/Insert content
4. 토큰 복사

### 11.2 Notion 데이터베이스 속성

| 속성         | 타입         | 설명                                   |
| ------------ | ------------ | -------------------------------------- |
| Name         | Title        | 이슈 제목                              |
| Issue Number | Number       | GitHub 이슈 번호                       |
| Status       | Select       | To Do / In Progress / In Review / Done |
| Priority     | Select       | High / Medium / Low                    |
| Assignee     | Text         | 담당자                                 |
| Labels       | Multi-select | 라벨                                   |
| Repository   | Select       | 레포 이름                              |
| URL          | URL          | GitHub 이슈 링크                       |

### 11.3 GitHub Secrets 설정

```bash
gh secret set NOTION_API_KEY --org agent-template-apps --body "secret_xxx"
gh secret set NOTION_DATABASE_ID --org agent-template-apps --body "db_xxx"
gh secret set GEMINI_API_KEY --org agent-template-apps --body "AIza..."
```

- `NOTION_API_KEY`: Notion Integration 토큰
- `NOTION_DATABASE_ID`: 데이터베이스 ID
- `GEMINI_API_KEY`: Gemini PR 리뷰용

---

## 12. 트러블슈팅

### 서브모듈 infra/가 비어있음

```bash
git submodule update --init --recursive
```

### pre-commit이 동작하지 않음

```bash
pip install pre-commit
pre-commit install
```

### 앱 시작 시 DB 연결 실패

```bash
# DB 상태 확인
docker compose -f shared-infra/docker-compose.dev.yml ps
# DB가 안 떠있으면
docker compose -f shared-infra/docker-compose.dev.yml up -d
```

### .env 파일이 없음

```bash
cp .env.example .env
# 로컬 DB를 docker-compose로 띄웠다면 기본값 그대로 사용 가능
```

### VS Code에서 자동 포맷이 안 됨

- 추천 확장 설치 확인 (VS Code 알림 또는 `.vscode/extensions.json` 참고)
- `Ctrl+Shift+P` → "Format Document" 수동 실행 후 기본 포맷터 선택
