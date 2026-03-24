# shared-infra

Agent Template Apps 전체 프로젝트의 공통 인프라 레포지토리입니다.
개발 표준, Claude Code 설정, CI/CD 워크플로우, 코드 포맷 설정, 로컬 개발 환경을 중앙에서 관리합니다.

## 프로젝트 구조

```
shared-infra/
├── CLAUDE.md                       # 공통 개발 규칙 (전체 앱이 참조)
│
├── .claude/                        # Claude Code 설정
│   ├── commands/                   #   슬래시 커맨드 (/start-task, /finish-task 등)
│   └── agents/                     #   서브에이전트 (@code-reviewer 등)
│
├── configs/                        # 코드 포맷/린트 설정 (앱 레포로 복사됨)
│   ├── ruff.toml                   #   Python 린트/포맷 (백엔드)
│   ├── .prettierrc                 #   TypeScript/JS 포맷 (프론트엔드)
│   ├── .editorconfig               #   IDE 공통 설정 (전체)
│   ├── vscode-backend.json         #   VS Code 설정 (백엔드)
│   ├── vscode-frontend.json        #   VS Code 설정 (프론트엔드)
│   ├── vscode-extensions-*.json    #   VS Code 추천 확장
│   ├── .pre-commit-config-backend.yaml   # pre-commit hook (백엔드)
│   └── .pre-commit-config-frontend.yaml  # pre-commit hook (프론트엔드)
│
├── docs/
│   ├── DEVELOPER_GUIDE.md          # 개발자 가이드 (온보딩 ~ 일상 개발)
│   └── standards/
│       ├── backend-standards.md    #   백엔드 개발 표준 (에러처리, API, 보안 등)
│       └── frontend-standards.md   #   프론트엔드 개발 표준 (컴포넌트, 상태관리 등)
│
├── scripts/
│   ├── developer-setup.sh          # 신규 개발자 온보딩 (최초 1회)
│   ├── start-dev.sh                # 일일 개발 서버 시작/중지
│   ├── sync-all-repos.sh           # shared-infra 변경 시 전체 앱 반영
│   ├── setup-repo.sh               # 단일 앱 설정 배포 (서브모듈 연결 후)
│   ├── setup-all-repos.sh          # 전체 앱 설정 배포
│   └── init-db.sql                 # 로컬 DB 초기화 SQL
│
├── docker-compose.dev.yml          # 로컬 개발용 PostgreSQL + Redis
│
├── .github/
│   ├── ISSUE_TEMPLATE/             # 이슈 템플릿 (feature, bugfix)
│   └── workflows/
│       ├── claude-review-reusable.yml  # Claude PR 자동 리뷰 (reusable)
│       ├── sync-notion.yml         # Notion 동기화
│       └── *-build.yml             # 빌드/배포 워크플로우
│
├── kubernetes/                     # K8s 배포 매니페스트
├── backends/                       # 인프라 미들웨어 (Traefik, Milvus, Phoenix)
└── data/                           # 공유 데이터
```

## 빠른 시작

### 신규 개발자 (최초 1회)

```bash
git clone https://github.com/agent-template-apps/shared-infra.git
cd shared-infra
./scripts/developer-setup.sh          # 대화형: 앱 선택 → 클론 → DB → 환경 셋업
./scripts/developer-setup.sh --all    # 전체 앱 한 번에
```

### 매일 개발 시작

```bash
cd shared-infra
./scripts/start-dev.sh --all          # DB + 전체 앱 기동
./scripts/start-dev.sh --status       # 상태 확인
./scripts/start-dev.sh --stop         # 전체 중지
```

### shared-infra 업데이트 반영

```bash
cd shared-infra
git pull
./scripts/sync-all-repos.sh           # 전체 앱에 설정 반영
./scripts/sync-all-repos.sh --push    # 반영 + 커밋 + push
```

## 상세 가이드

개발 플로우, Claude Code 사용법, 코드 포맷 규칙 등 상세 내용은
[개발자 가이드](docs/DEVELOPER_GUIDE.md)를 참고하세요.
