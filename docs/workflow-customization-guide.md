# 워크플로우 커스터마이징 가이드

## 1. 개요

이 문서는 `agent-template-apps` 템플릿을 복사하여 새 프로젝트를 시작하는 팀이, 개발 워크플로우의 규칙과 설정을 자기 프로젝트에 맞게 수정할 때 **어디를 수정해야 하는지** 안내합니다.

### 전체 워크플로우 흐름

```
/start-task → 개발 진행 → /finish-task → PR 리뷰 (AI + PL)
   │              │              │              │
   ├─ 이슈 확인    ├─ 코드 작성    ├─ 린트/테스트   ├─ Gemini 자동 리뷰
   ├─ 계획 수립    ├─ @code-reviewer├─ 커밋 생성    └─ PL 최종 Approve
   └─ 브랜치 생성  ├─ @test-runner  ├─ PR 생성
                  └─ 자동 포맷     └─ 이슈 업데이트
```

### 핵심 원칙

> **shared-infra가 단일 진실 원본(Single Source of Truth)**
>
> 설정 수정은 반드시 `shared-infra`에서 하고, 스크립트를 통해 각 앱에 배포합니다.
> 개별 앱에서 직접 수정하면 다음 동기화 시 덮어씌워집니다.

---

## 2. STEP 1: 태스크 시작 (`/start-task`)

### 수행 내용

1. GitHub Issue 내용 확인 (`gh issue view`)
2. 이슈 분석 후 구현 계획 수립
3. 작업 브랜치 생성 (`feat/{앱약어}/{이슈번호}-{설명}`)
4. 이슈에 "🚀 작업을 시작합니다" 코멘트

### 커스터마이징 포인트

| 수정 대상 | 파일 위치 | 설명 |
|-----------|-----------|------|
| 브랜치 네이밍 규칙 | `shared-infra/CLAUDE.md` — Git 워크플로우 섹션 | `feat/`, `fix/` 접두사, 앱 약어 목록 등 |
| /start-task 동작 로직 | `.claude/commands/start-task.md` | 브랜치 생성 방식, 코멘트 형식, 계획 수립 프롬프트 |
| 이슈 템플릿 (기능) | `.github/ISSUE_TEMPLATE/feature.yml` | 필드 구성, 라벨, 난이도 선택지 (S/M/L/XL) |
| 이슈 템플릿 (버그) | `.github/ISSUE_TEMPLATE/bugfix.yml` | 필드 구성, 라벨 |

---

## 3. STEP 2: 개발 진행

### 수행 내용

- Claude Code 또는 VS Code로 코드 작성
- `@code-reviewer`로 코드 리뷰 요청
- `@test-runner`로 테스트 실행
- 저장 시 자동 포맷 (VS Code) + pre-commit hook으로 포맷 강제

### 커스터마이징 포인트

#### 코드 리뷰 규칙

| 수정 대상 | 파일 위치 | 설명 |
|-----------|-----------|------|
| 리뷰 검사 항목 | `.claude/agents/code-reviewer.md` | 체크리스트 항목, 심각도 기준 (🔴/🟡/🟢), 출력 형식 |
| 프로젝트 코딩 규칙 | `shared-infra/CLAUDE.md` + 각 앱 `CLAUDE.md` | 에러 코드 체계, API 응답 형식, 보안 규칙 등 |

#### 테스트 실행

| 수정 대상 | 파일 위치 | 설명 |
|-----------|-----------|------|
| 테스트 실행 방식 | `.claude/agents/test-runner.md` | 테스트 명령어 (`uv run pytest`, `pnpm test`), 리포트 형식 |

#### 코드 포맷 & 린트

| 수정 대상 | 파일 위치 (원본) | 배포 위치 (앱) | 설명 |
|-----------|------------------|----------------|------|
| Python 린트 규칙 | `configs/ruff.toml` | `./ruff.toml` (심링크) | 줄 길이, 활성 규칙, import 순서, 따옴표 스타일 |
| JS/TS 포맷 규칙 | `configs/.prettierrc` | `./.prettierrc` (심링크) | 세미콜론, 따옴표, 줄 길이, 탭 너비 |
| 에디터 공통 설정 | `configs/.editorconfig` | `./.editorconfig` (심링크) | 인코딩, 줄바꿈, 인덴트 크기 |
| 백엔드 pre-commit | `configs/.pre-commit-config-backend.yaml` | `.pre-commit-config.yaml` (복사) | Ruff 버전, hook 종류, 파일 크기 제한 |
| 프론트엔드 pre-commit | `configs/.pre-commit-config-frontend.yaml` | `.pre-commit-config.yaml` (복사) | Prettier 버전, hook 종류 |
| VS Code 백엔드 설정 | `configs/vscode-backend.json` | `.vscode/settings.json` (복사) | 자동 포맷 설정, 기본 포맷터 |
| VS Code 프론트엔드 설정 | `configs/vscode-frontend.json` | `.vscode/settings.json` (복사) | 자동 포맷 설정, 기본 포맷터 |
| VS Code 추천 확장 (백엔드) | `configs/vscode-extensions-backend.json` | `.vscode/extensions.json` (복사) | 추천 확장 목록 |
| VS Code 추천 확장 (프론트엔드) | `configs/vscode-extensions-frontend.json` | `.vscode/extensions.json` (복사) | 추천 확장 목록 |

#### 배포 방법

```bash
# 단일 앱에 설정 배포
./infra/scripts/setup-repo.sh

# 전체 앱에 일괄 배포
./scripts/sync-all-repos.sh --push

# 배포 로직 자체를 수정하려면
# → scripts/setup-repo.sh (심링크 vs 복사, 파일 경로 매핑)
```

---

## 4. STEP 3: 태스크 완료 (`/finish-task`)

### 수행 내용

6단계 자동화:

1. **변경사항 분석** — `git diff`로 변경 파일 파악
2. **린트 & 테스트** — 백엔드: `uv run ruff check .`, 프론트: `pnpm lint`
3. **커밋 메시지 자동 생성** — Conventional Commits 형식, 사용자 확인 후 진행
4. **커밋 & Push** — 승인된 메시지로 커밋, `origin`에 Push
5. **PR 메시지 자동 생성** — 제목/개요/변경내용/테스트 섹션, 사용자 확인 후 진행
6. **PR 생성 & 이슈 업데이트** — `gh pr create`, 이슈에 완료 코멘트

### 커스터마이징 포인트

| 수정 대상 | 파일 위치 | 설명 |
|-----------|-----------|------|
| /finish-task 전체 동작 | `.claude/commands/finish-task.md` | 6단계 순서, 각 단계 로직, 사용자 확인 프롬프트 |
| 커밋 메시지 형식 | `docs/conventions/git/commit-message.md` | type 종류, scope 규칙, 본문/꼬리 형식 |
| PR 본문 템플릿 | `docs/conventions/git/pull-request.md` | 제목 형식, 본문 섹션 (개요/변경내용/테스트), `Closes #` 연결 |
| 린트 실행 명령 | `.claude/commands/finish-task.md` | 백엔드: `uv run ruff check .`, 프론트: `pnpm lint` |

---

## 5. STEP 4: PR 리뷰 (자동 + 수동)

### 수행 내용

- **1단계: AI 자동 리뷰** — PR 생성/업데이트 시 Gemini가 인라인 코멘트 + 요약 피드백
- **2단계: PL 최종 리뷰** — Gemini 리뷰 결과 확인 후 Approve / Request Changes

### 커스터마이징 포인트

| 수정 대상 | 파일 위치 | 설명 |
|-----------|-----------|------|
| 리뷰 워크플로우 (공통) | `.github/workflows/gemini-review-reusable.yml` | 트리거 조건, 타임아웃, 모델 선택 |
| 백엔드 리뷰 프롬프트 | `gemini-review-reusable.yml` 내 `REVIEW_PROMPT` (backend) | 아키텍처, 에러 처리, 보안, 코드 품질, 테스트 검사 항목 |
| 프론트엔드 리뷰 프롬프트 | `gemini-review-reusable.yml` 내 `REVIEW_PROMPT` (frontend) | 컴포넌트 구조, 보안, 국제화 검사 항목 |
| 심각도 태그 | `gemini-review-reusable.yml` | `[CRITICAL/HIGH/MEDIUM/LOW]` 기준 |
| 앱별 호출 워크플로우 | 각 앱 `.github/workflows/claude-review.yml` | `app_type`, `app_name` 파라미터 (`setup-repo.sh`가 자동 생성) |
| 워크플로우 생성 로직 | `scripts/setup-repo.sh` (`generate_claude_review_workflow` 함수) | 앱 타입 판별, 워크플로우 파일 자동 생성 |
| Notion 동기화 | `.github/workflows/sync-notion.yml` | 이슈 상태 → Notion 매핑 (To Do / In Progress / In Review / Done) |

---

## 6. 설정 변경 후 전체 배포 방법

### 배포 절차

```bash
# 1. shared-infra에서 설정 수정 & 커밋 & push
cd shared-infra
# (설정 파일 수정)
git add . && git commit -m "chore(configs): 설정 변경 내용" && git push

# 2-A. 전체 앱에 일괄 반영
./scripts/sync-all-repos.sh --push

# 2-B. 또는 개별 앱에서 수동 반영
cd ../backend-auth
git submodule update --remote infra
./infra/scripts/setup-repo.sh
```

### 심링크 vs 복사 파일의 차이

| 유형 | 대상 파일 | 반영 방법 |
|------|-----------|-----------|
| **심링크** | `.claude/commands/`, `.claude/agents/`, `ruff.toml`, `.prettierrc`, `.editorconfig` | `git submodule update --remote`만으로 **자동 반영** |
| **복사** | `.pre-commit-config.yaml`, `.vscode/settings.json`, `.github/workflows/` | `setup-repo.sh` **재실행 필요** |

> 심링크 파일은 submodule만 업데이트하면 즉시 최신 설정이 적용됩니다.
> 복사 파일은 `setup-repo.sh`를 다시 실행해야 최신 내용이 덮어씌워집니다.

---

## 7. 새 프로젝트에서 이 템플릿 적용 시 필수 수정 항목

템플릿을 복사한 후 최소한 아래 항목을 수정해야 합니다:

### 기본 설정

- [ ] **GitHub org 이름 변경** — 워크플로우 내 `agent-template-apps` 참조를 새 org 이름으로 교체
- [ ] **GitHub Secrets 설정** — 각 레포 또는 org 레벨에서 설정:
  - `NOTION_API_KEY`, `NOTION_DATABASE_ID` — Notion 동기화용
  - `ANTHROPIC_API_KEY` — Claude Code 리뷰용
  - `GEMINI_API_KEY` — Gemini PR 리뷰용
  - ACR 자격증명 등 — 빌드/배포 워크플로우용

### 프로젝트 규칙

- [ ] **`shared-infra/CLAUDE.md`** — 프로젝트명, 레포 목록, API 규칙, 에러 코드 체계 등 수정
- [ ] **각 앱 `CLAUDE.md`** — 앱별 기술 스택, 디렉토리 구조, 코딩 규칙 수정
- [ ] **`.env.example`** — 각 앱의 환경변수 템플릿 수정

### 인프라

- [ ] **`docker-compose.dev.yml`** — DB 설정, 포트, 볼륨 등 프로젝트에 맞게 수정
- [ ] **빌드/배포 워크플로우** — ACR 레지스트리, K8s 클러스터, 네임스페이스 등 수정
- [ ] **`sync-all-repos.sh`** — `REPOS` 배열을 새 프로젝트의 레포 목록으로 변경
