#!/bin/bash
# 앱 레포 초기 셋업: 서브모듈 초기화 + 심볼릭 링크로 Claude Code 설정 연결
#
# 사용법: 각 앱 레포의 루트에서 실행
#   cd ~/Workspace/GitHub/backend-auth
#   ./infra/scripts/setup-repo.sh
#
# 또는 서브모듈 초기화 전이라면:
#   git submodule update --init --recursive
#   ./infra/scripts/setup-repo.sh

set -e

REPO_DIR="$(pwd)"
REPO_NAME="$(basename "$REPO_DIR")"

echo "=== ${REPO_NAME} 셋업 ==="

# 1. 서브모듈 초기화 (아직 안 됐으면)
if [ ! -f "${REPO_DIR}/infra/CLAUDE.md" ]; then
  echo "▶ 서브모듈 초기화 중..."
  git submodule update --init --recursive
fi

if [ ! -f "${REPO_DIR}/infra/CLAUDE.md" ]; then
  echo "❌ infra/ 서브모듈이 비어있습니다. 먼저 git submodule update --init 실행하세요."
  exit 1
fi

echo "✓ infra/ 서브모듈 확인 완료"

# 2. .claude/ 개별 파일 심볼릭 링크 생성
#    → 디렉토리 단위가 아닌 개별 파일/서브디렉토리 symlink으로
#      shared + per-repo custom이 공존 가능
echo ""
echo "▶ .claude/ 심볼릭 링크 설정 중 (개별 파일 방식)..."

# 기존 디렉토리 symlink이 있으면 실제 디렉토리로 교체
for subdir in commands agents skills; do
  if [ -L "${REPO_DIR}/.claude/${subdir}" ]; then
    echo "  ↻ .claude/${subdir} 디렉토리 symlink → 실제 디렉토리로 전환"
    rm "${REPO_DIR}/.claude/${subdir}"
  fi
done

mkdir -p "${REPO_DIR}/.claude/commands"
mkdir -p "${REPO_DIR}/.claude/agents"
mkdir -p "${REPO_DIR}/.claude/skills"

# commands: 개별 .md 파일 symlink
for file in "${REPO_DIR}/infra/.claude/commands/"*.md; do
  [ -f "$file" ] || continue
  name=$(basename "$file")
  target="../../infra/.claude/commands/${name}"
  ln -sf "$target" "${REPO_DIR}/.claude/commands/${name}"
done
echo "  ✓ .claude/commands/ — shared 파일 개별 symlink 완료"

# agents: 개별 .md 파일 symlink
for file in "${REPO_DIR}/infra/.claude/agents/"*.md; do
  [ -f "$file" ] || continue
  name=$(basename "$file")
  target="../../infra/.claude/agents/${name}"
  ln -sf "$target" "${REPO_DIR}/.claude/agents/${name}"
done
echo "  ✓ .claude/agents/ — shared 파일 개별 symlink 완료"

# skills: 서브디렉토리 단위 symlink (커스텀 디렉토리가 이미 있으면 건드리지 않음)
for dir in "${REPO_DIR}/infra/.claude/skills/"*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  target="../../infra/.claude/skills/${name}"
  if [ ! -e "${REPO_DIR}/.claude/skills/${name}" ]; then
    ln -sf "$target" "${REPO_DIR}/.claude/skills/${name}"
  fi
done
echo "  ✓ .claude/skills/ — shared 스킬 개별 symlink 완료"

# 3. .github/ 심볼릭 링크 (Issue 템플릿, Notion 동기화)
echo ""
echo "▶ .github/ 설정 연결 중..."

mkdir -p "${REPO_DIR}/.github"

# ISSUE_TEMPLATE 심볼릭 링크
if [ -L "${REPO_DIR}/.github/ISSUE_TEMPLATE" ]; then
  rm "${REPO_DIR}/.github/ISSUE_TEMPLATE"
elif [ -d "${REPO_DIR}/.github/ISSUE_TEMPLATE" ]; then
  mv "${REPO_DIR}/.github/ISSUE_TEMPLATE" "${REPO_DIR}/.github/ISSUE_TEMPLATE.bak.$(date +%s)"
fi
ln -s ../infra/.github/ISSUE_TEMPLATE "${REPO_DIR}/.github/ISSUE_TEMPLATE"
echo "  ✓ .github/ISSUE_TEMPLATE → infra/.github/ISSUE_TEMPLATE"

# Notion sync workflow 복사 (workflow 파일은 심볼릭 링크 불가 - GitHub Actions 제한)
mkdir -p "${REPO_DIR}/.github/workflows"
if [ -f "${REPO_DIR}/infra/.github/workflows/sync-notion.yml" ]; then
  cp "${REPO_DIR}/infra/.github/workflows/sync-notion.yml" "${REPO_DIR}/.github/workflows/"
  echo "  ✓ .github/workflows/sync-notion.yml 복사 (워크플로우는 심볼릭 링크 불가)"
fi

# 4. 코드 포맷/린트 설정 배포
echo ""
echo "▶ 코드 포맷/린트 설정 배포 중..."

# EditorConfig (모든 레포 공통)
if [ -f "${REPO_DIR}/infra/configs/.editorconfig" ]; then
  cp "${REPO_DIR}/infra/configs/.editorconfig" "${REPO_DIR}/.editorconfig"
  echo "  ✓ .editorconfig 복사"
fi

# 백엔드: ruff.toml
if [[ "$REPO_NAME" == backend-* ]]; then
  if [ -f "${REPO_DIR}/infra/configs/ruff.toml" ]; then
    cp "${REPO_DIR}/infra/configs/ruff.toml" "${REPO_DIR}/ruff.toml"
    echo "  ✓ ruff.toml 복사 (Python 린트/포맷)"
  fi
fi

# 프론트엔드: .prettierrc
if [[ "$REPO_NAME" == frontend* ]]; then
  if [ -f "${REPO_DIR}/infra/configs/.prettierrc" ]; then
    cp "${REPO_DIR}/infra/configs/.prettierrc" "${REPO_DIR}/.prettierrc"
    echo "  ✓ .prettierrc 복사 (TypeScript/JS 포맷)"
  fi
fi

# 5. Gemini PR 리뷰 워크플로우 배포
echo ""
echo "▶ Gemini PR 리뷰 워크플로우 설정 중..."

mkdir -p "${REPO_DIR}/.github/workflows"

# gemini-review.yml 생성 (reusable workflow 호출)
if [[ "$REPO_NAME" == backend-* ]]; then
  APP_TYPE="backend"
elif [[ "$REPO_NAME" == frontend* ]]; then
  APP_TYPE="frontend"
else
  APP_TYPE=""
fi

if [ -n "$APP_TYPE" ]; then
  cat > "${REPO_DIR}/.github/workflows/gemini-review.yml" << YAML_EOF
# Gemini PR 자동 리뷰
# shared-infra의 reusable workflow를 호출합니다.
name: Gemini Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    uses: agent-template-apps/shared-infra/.github/workflows/gemini-review-reusable.yml@main
    with:
      app_type: ${APP_TYPE}
      app_name: ${REPO_NAME}
    secrets: inherit
YAML_EOF
  echo "  ✓ .github/workflows/gemini-review.yml 생성 (app_type: ${APP_TYPE})"
fi

# 앱별 변수 정의 (VS Code launch.json, README 등에서 사용)
case "$REPO_NAME" in
  backend-auth)         APP_DESC="인증/JWT/사용자관리"; APP_PORT="8001"; APP_ENTRY="app/main.py"; APP_CONSOLE="internalConsole"; APP_RUN="uv run uvicorn app.main:app --port 8001 --reload" ;;
  backend-base)         APP_DESC="기본 API/조직관리"; APP_PORT="8002"; APP_ENTRY="app/main.py"; APP_CONSOLE="internalConsole"; APP_RUN="uv run uvicorn app.main:app --port 8002 --reload" ;;
  backend-chat)         APP_DESC="채팅/LLM 스트리밍"; APP_PORT="8003"; APP_ENTRY="app/main.py"; APP_CONSOLE="internalConsole"; APP_RUN="uv run uvicorn app.main:app --port 8003 --reload" ;;
  backend-llm-gateway)  APP_DESC="LLM 라우팅/프롬프트관리"; APP_PORT="8080"; APP_ENTRY="app/main.py"; APP_CONSOLE="internalConsole"; APP_RUN="uv run uvicorn app.main:app --port 8080 --reload" ;;
  backend-mcp)          APP_DESC="MCP 도구/벡터DB"; APP_PORT="8084"; APP_ENTRY="server/server_sse.py"; APP_CONSOLE="integratedTerminal"; APP_RUN="uv run uvicorn app.main:app --port 8084 --reload" ;;
  frontend)             APP_DESC="프론트엔드 (admin :3001 / chat :3000)"; APP_PORT="3000/3001"; APP_RUN="cd chat && pnpm dev  # 또는 cd admin && pnpm dev" ;;
  *)                    APP_DESC=""; APP_PORT=""; APP_RUN="" ;;
esac

# 6. VS Code 설정 배포 (.vscode/settings.json + extensions.json)
echo ""
echo "▶ VS Code 설정 배포 중..."

mkdir -p "${REPO_DIR}/.vscode"

if [[ "$REPO_NAME" == backend-* ]]; then
  if [ -f "${REPO_DIR}/infra/configs/vscode-backend.json" ]; then
    cp "${REPO_DIR}/infra/configs/vscode-backend.json" "${REPO_DIR}/.vscode/settings.json"
    echo "  ✓ .vscode/settings.json 복사 (Python/Ruff 자동 포맷)"
  fi
  if [ -f "${REPO_DIR}/infra/configs/vscode-extensions-backend.json" ]; then
    cp "${REPO_DIR}/infra/configs/vscode-extensions-backend.json" "${REPO_DIR}/.vscode/extensions.json"
    echo "  ✓ .vscode/extensions.json 복사 (추천 확장 목록)"
  fi
elif [[ "$REPO_NAME" == frontend* ]]; then
  if [ -f "${REPO_DIR}/infra/configs/vscode-frontend.json" ]; then
    cp "${REPO_DIR}/infra/configs/vscode-frontend.json" "${REPO_DIR}/.vscode/settings.json"
    echo "  ✓ .vscode/settings.json 복사 (Prettier 자동 포맷)"
  fi
  if [ -f "${REPO_DIR}/infra/configs/vscode-extensions-frontend.json" ]; then
    cp "${REPO_DIR}/infra/configs/vscode-extensions-frontend.json" "${REPO_DIR}/.vscode/extensions.json"
    echo "  ✓ .vscode/extensions.json 복사 (추천 확장 목록)"
  fi
fi

# launch.json 배포 (F5 디버그 설정)
if [[ "$REPO_NAME" == backend-* ]]; then
  if [ -f "${REPO_DIR}/infra/configs/vscode-launch-backend.json" ]; then
    sed -e "s/__APP_NAME__/${REPO_NAME}/g" \
        -e "s|__APP_ENTRY__|${APP_ENTRY}|g" \
        -e "s/__APP_CONSOLE__/${APP_CONSOLE}/g" \
        "${REPO_DIR}/infra/configs/vscode-launch-backend.json" \
        > "${REPO_DIR}/.vscode/launch.json"
    echo "  ✓ .vscode/launch.json 생성 (debugpy: ${APP_ENTRY})"
  fi
elif [[ "$REPO_NAME" == frontend* ]]; then
  if [ -f "${REPO_DIR}/infra/configs/vscode-launch-frontend.json" ]; then
    cp "${REPO_DIR}/infra/configs/vscode-launch-frontend.json" "${REPO_DIR}/.vscode/launch.json"
    echo "  ✓ .vscode/launch.json 복사 (Node/pnpm dev)"
  fi
fi

# 7. pre-commit hook 설정 배포
echo ""
echo "▶ pre-commit 설정 배포 중..."

if [[ "$REPO_NAME" == backend-* ]]; then
  if [ -f "${REPO_DIR}/infra/configs/.pre-commit-config-backend.yaml" ]; then
    cp "${REPO_DIR}/infra/configs/.pre-commit-config-backend.yaml" "${REPO_DIR}/.pre-commit-config.yaml"
    echo "  ✓ .pre-commit-config.yaml 복사 (Ruff 린트/포맷 hook)"
  fi
elif [[ "$REPO_NAME" == frontend* ]]; then
  if [ -f "${REPO_DIR}/infra/configs/.pre-commit-config-frontend.yaml" ]; then
    cp "${REPO_DIR}/infra/configs/.pre-commit-config-frontend.yaml" "${REPO_DIR}/.pre-commit-config.yaml"
    echo "  ✓ .pre-commit-config.yaml 복사 (Prettier 포맷 hook)"
  fi
fi

# pre-commit 자동 설치 (pre-commit이 설치되어 있는 경우)
if command -v pre-commit &> /dev/null; then
  cd "${REPO_DIR}"
  pre-commit install --allow-missing-config 2>/dev/null
  echo "  ✓ pre-commit hook 설치 완료 (git commit 시 자동 실행)"
else
  echo "  ⚠️  pre-commit이 설치되어 있지 않습니다."
  echo "     설치: pip install pre-commit && pre-commit install"
fi

# 8. README.md 생성 (기존 README.md가 없거나 자동생성된 것이면 덮어쓰기)
echo ""
echo "▶ README.md 생성 중..."

if [ -n "$APP_DESC" ]; then
  cat > "${REPO_DIR}/README.md" << README_EOF
# ${REPO_NAME}

${APP_DESC} — 포트 :${APP_PORT}

## 빠른 시작

> 최초 셋업이 안 됐다면 [개발자 가이드 — 최초 셋업](https://github.com/agent-template-apps/shared-infra/blob/main/docs/DEVELOPER_GUIDE.md#2-%EC%B5%9C%EC%B4%88-%EC%85%8B%EC%97%85-%EC%8B%A0%EA%B7%9C-%EA%B0%9C%EB%B0%9C%EC%9E%90)을 먼저 진행하세요.

\`\`\`bash
# 서버 실행
${APP_RUN}
\`\`\`

## 개발 가이드

모든 개발 워크플로우, 코드 표준, 스크립트 사용법은 shared-infra에서 관리합니다.

- [개발자 가이드](https://github.com/agent-template-apps/shared-infra/blob/main/docs/DEVELOPER_GUIDE.md) — 셋업, 일일 개발, 워크플로우, 트러블슈팅
- [백엔드 개발 표준](https://github.com/agent-template-apps/shared-infra/blob/main/docs/standards/backend-standards.md)
- [프론트엔드 개발 표준](https://github.com/agent-template-apps/shared-infra/blob/main/docs/standards/frontend-standards.md)

## 주요 명령어

| 명령어 | 설명 |
|--------|------|
| \`claude\` → \`/start-task {이슈번호}\` | 태스크 시작 (브랜치 생성) |
| \`claude\` → \`/finish-task\` | 린트 → 커밋 → PR 자동 생성 |
| \`./infra/scripts/setup-repo.sh\` | shared-infra 설정 재배포 |
README_EOF
  echo "  ✓ README.md 생성 완료"
fi

# 10. .gitignore에 심볼릭 링크 관련 항목 추가 (이미 있으면 스킵)
echo ""
echo "▶ .gitignore 확인 중..."
touch "${REPO_DIR}/.gitignore"

# 심볼릭 링크 파일은 git에 포함되어야 하므로 별도 제외 불필요
# 단, 백업 파일은 제외
if ! grep -q "*.bak.*" "${REPO_DIR}/.gitignore" 2>/dev/null; then
  echo "*.bak.*" >> "${REPO_DIR}/.gitignore"
  echo "  ✓ .gitignore에 백업 파일 제외 추가"
fi

# 결과 확인
echo ""
echo "=== ${REPO_NAME} 셋업 완료 ==="
echo ""
echo "구조:"
echo "  ${REPO_NAME}/"
echo "  ├── CLAUDE.md                    ← 앱별 규칙 (@infra/CLAUDE.md 참조)"
echo "  ├── .editorconfig                ← 공통 에디터 설정"
if [[ "$REPO_NAME" == backend-* ]]; then
echo "  ├── ruff.toml                    ← Python 린트/포맷"
echo "  ├── .pre-commit-config.yaml      ← 커밋 전 자동 검사"
fi
if [[ "$REPO_NAME" == frontend* ]]; then
echo "  ├── .prettierrc                  ← TS/JS 포맷"
echo "  ├── .pre-commit-config.yaml      ← 커밋 전 자동 검사"
fi
echo "  ├── .vscode/"
echo "  │   ├── settings.json            ← 저장 시 자동 포맷"
echo "  │   ├── extensions.json          ← 추천 확장 목록"
echo "  │   └── launch.json              ← F5 디버그 설정"
echo "  ├── .claude/"
echo "  │   ├── commands/  (개별 파일 symlink + 커스텀 추가 가능)"
echo "  │   ├── agents/   (개별 파일 symlink + 커스텀 추가 가능)"
echo "  │   └── skills/   (개별 서브디렉토리 symlink + 커스텀 추가 가능)"
echo "  ├── .github/"
echo "  │   ├── ISSUE_TEMPLATE → infra/.github/ISSUE_TEMPLATE (심볼릭 링크)"
echo "  │   ├── workflows/gemini-review.yml          (자동 생성)"
echo "  │   └── workflows/sync-notion.yml            (복사본)"
echo "  └── infra/                       ← shared-infra 서브모듈"
echo ""
echo "shared-infra 업데이트 반영:"
echo "  cd ${REPO_NAME}"
echo "  git submodule update --remote infra"
echo "  ./infra/scripts/setup-repo.sh    ← 설정 파일 재배포"
echo "  → 심볼릭 링크는 자동 갱신, 복사 파일은 재실행 필요"
