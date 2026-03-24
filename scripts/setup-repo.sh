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

# 2. .claude/ 심볼릭 링크 생성
#    → infra/.claude/ 의 commands, agents를 앱 레포 루트에서 참조
echo ""
echo "▶ .claude/ 심볼릭 링크 설정 중..."

mkdir -p "${REPO_DIR}/.claude"

# commands 심볼릭 링크
if [ -L "${REPO_DIR}/.claude/commands" ]; then
  rm "${REPO_DIR}/.claude/commands"
elif [ -d "${REPO_DIR}/.claude/commands" ]; then
  echo "  ⚠️  .claude/commands/ 가 이미 디렉토리로 존재합니다. 백업 후 교체합니다."
  mv "${REPO_DIR}/.claude/commands" "${REPO_DIR}/.claude/commands.bak.$(date +%s)"
fi
ln -s ../infra/.claude/commands "${REPO_DIR}/.claude/commands"
echo "  ✓ .claude/commands → infra/.claude/commands"

# agents 심볼릭 링크
if [ -L "${REPO_DIR}/.claude/agents" ]; then
  rm "${REPO_DIR}/.claude/agents"
elif [ -d "${REPO_DIR}/.claude/agents" ]; then
  echo "  ⚠️  .claude/agents/ 가 이미 디렉토리로 존재합니다. 백업 후 교체합니다."
  mv "${REPO_DIR}/.claude/agents" "${REPO_DIR}/.claude/agents.bak.$(date +%s)"
fi
ln -s ../infra/.claude/agents "${REPO_DIR}/.claude/agents"
echo "  ✓ .claude/agents → infra/.claude/agents"

# skills (있으면)
if [ -d "${REPO_DIR}/infra/.claude/skills" ]; then
  if [ -L "${REPO_DIR}/.claude/skills" ]; then
    rm "${REPO_DIR}/.claude/skills"
  elif [ -d "${REPO_DIR}/.claude/skills" ]; then
    mv "${REPO_DIR}/.claude/skills" "${REPO_DIR}/.claude/skills.bak.$(date +%s)"
  fi
  ln -s ../infra/.claude/skills "${REPO_DIR}/.claude/skills"
  echo "  ✓ .claude/skills → infra/.claude/skills"
fi

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
if [[ "$REPO_NAME" == frontend-* ]]; then
  if [ -f "${REPO_DIR}/infra/configs/.prettierrc" ]; then
    cp "${REPO_DIR}/infra/configs/.prettierrc" "${REPO_DIR}/.prettierrc"
    echo "  ✓ .prettierrc 복사 (TypeScript/JS 포맷)"
  fi
fi

# 5. Claude PR 리뷰 워크플로우 배포
echo ""
echo "▶ Claude PR 리뷰 워크플로우 설정 중..."

mkdir -p "${REPO_DIR}/.github/workflows"

# claude-review.yml 생성 (reusable workflow 호출)
if [[ "$REPO_NAME" == backend-* ]]; then
  APP_TYPE="backend"
elif [[ "$REPO_NAME" == frontend-* ]]; then
  APP_TYPE="frontend"
else
  APP_TYPE=""
fi

if [ -n "$APP_TYPE" ]; then
  cat > "${REPO_DIR}/.github/workflows/claude-review.yml" << YAML_EOF
# Claude Code PR 자동 리뷰
# shared-infra의 reusable workflow를 호출합니다.
name: Claude Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    uses: agent-template-apps/shared-infra/.github/workflows/claude-review-reusable.yml@main
    with:
      app_type: ${APP_TYPE}
      app_name: ${REPO_NAME}
    secrets: inherit
YAML_EOF
  echo "  ✓ .github/workflows/claude-review.yml 생성 (app_type: ${APP_TYPE})"
fi

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
elif [[ "$REPO_NAME" == frontend-* ]]; then
  if [ -f "${REPO_DIR}/infra/configs/vscode-frontend.json" ]; then
    cp "${REPO_DIR}/infra/configs/vscode-frontend.json" "${REPO_DIR}/.vscode/settings.json"
    echo "  ✓ .vscode/settings.json 복사 (Prettier 자동 포맷)"
  fi
  if [ -f "${REPO_DIR}/infra/configs/vscode-extensions-frontend.json" ]; then
    cp "${REPO_DIR}/infra/configs/vscode-extensions-frontend.json" "${REPO_DIR}/.vscode/extensions.json"
    echo "  ✓ .vscode/extensions.json 복사 (추천 확장 목록)"
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
elif [[ "$REPO_NAME" == frontend-* ]]; then
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

# 8. .gitignore에 심볼릭 링크 관련 항목 추가 (이미 있으면 스킵)
echo ""
echo "▶ .gitignore 확인 중..."
touch "${REPO_DIR}/.gitignore"

# 심볼릭 링크 파일은 git에 포함되어야 하므로 별도 제외 불필요
# 단, 백업 파일은 제외
if ! grep -q "*.bak.*" "${REPO_DIR}/.gitignore" 2>/dev/null; then
  echo "*.bak.*" >> "${REPO_DIR}/.gitignore"
  echo "  ✓ .gitignore에 백업 파일 제외 추가"
fi

# 8. 결과 확인
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
if [[ "$REPO_NAME" == frontend-* ]]; then
echo "  ├── .prettierrc                  ← TS/JS 포맷"
echo "  ├── .pre-commit-config.yaml      ← 커밋 전 자동 검사"
fi
echo "  ├── .vscode/"
echo "  │   ├── settings.json            ← 저장 시 자동 포맷"
echo "  │   └── extensions.json          ← 추천 확장 목록"
echo "  ├── .claude/"
echo "  │   ├── commands → infra/.claude/commands   (심볼릭 링크)"
echo "  │   └── agents  → infra/.claude/agents      (심볼릭 링크)"
echo "  ├── .github/"
echo "  │   ├── ISSUE_TEMPLATE → infra/.github/ISSUE_TEMPLATE (심볼릭 링크)"
echo "  │   ├── workflows/claude-review.yml          (자동 생성)"
echo "  │   └── workflows/sync-notion.yml            (복사본)"
echo "  └── infra/                       ← shared-infra 서브모듈"
echo ""
echo "shared-infra 업데이트 반영:"
echo "  cd ${REPO_NAME}"
echo "  git submodule update --remote infra"
echo "  ./infra/scripts/setup-repo.sh    ← 설정 파일 재배포"
echo "  → 심볼릭 링크는 자동 갱신, 복사 파일은 재실행 필요"
