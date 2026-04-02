#!/bin/bash
# shared-infra의 .claude/ 설정(커맨드, 에이전트)과 GitHub 템플릿을
# 모든 앱 레포에 배포하는 스크립트
#
# 사용법: cd shared-infra && ./scripts/deploy-claude-config.sh
# 옵션:   --dry-run  실제 복사 없이 미리보기

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$INFRA_DIR")"

DRY_RUN=false
if [ "$1" = "--dry-run" ]; then
  DRY_RUN=true
  echo "[DRY RUN] 실제 파일 복사 없이 미리보기만 합니다."
  echo ""
fi

REPOS=(
  "backend-auth"
  "backend-base"
  "backend-chat"
  "backend-llm-gateway"
  "backend-mcp"
  "frontend"
)

echo "=== Claude Code 설정 배포 ==="
echo "소스: ${INFRA_DIR}/.claude/"
echo "대상: ${#REPOS[@]}개 앱 레포"
echo ""

for repo in "${REPOS[@]}"; do
  REPO_DIR="${PARENT_DIR}/${repo}"

  if [ ! -d "$REPO_DIR" ]; then
    echo "⚠️  ${repo}: 디렉토리 없음 (${REPO_DIR}), 건너뜀"
    continue
  fi

  echo "▶ ${repo}"

  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY] .claude/commands/ → ${repo}/.claude/commands/"
    echo "  [DRY] .claude/agents/ → ${repo}/.claude/agents/"
    echo "  [DRY] .github/ISSUE_TEMPLATE/ → ${repo}/.github/ISSUE_TEMPLATE/"
    echo "  [DRY] .github/workflows/sync-notion.yml → ${repo}/.github/workflows/"
    echo "  [DRY] GEMINI.md → ${repo}/GEMINI.md"
  else
    # .claude/commands 복사
    mkdir -p "${REPO_DIR}/.claude/commands"
    cp -r "${INFRA_DIR}/.claude/commands/"* "${REPO_DIR}/.claude/commands/" 2>/dev/null || true
    echo "  ✓ .claude/commands/ 복사 완료"

    # .claude/agents 복사
    mkdir -p "${REPO_DIR}/.claude/agents"
    cp -r "${INFRA_DIR}/.claude/agents/"* "${REPO_DIR}/.claude/agents/" 2>/dev/null || true
    echo "  ✓ .claude/agents/ 복사 완료"

    # GitHub Issue 템플릿 복사
    mkdir -p "${REPO_DIR}/.github/ISSUE_TEMPLATE"
    cp -r "${INFRA_DIR}/.github/ISSUE_TEMPLATE/"* "${REPO_DIR}/.github/ISSUE_TEMPLATE/" 2>/dev/null || true
    echo "  ✓ .github/ISSUE_TEMPLATE/ 복사 완료"

    # Notion 동기화 워크플로우 복사
    mkdir -p "${REPO_DIR}/.github/workflows"
    cp "${INFRA_DIR}/.github/workflows/sync-notion.yml" "${REPO_DIR}/.github/workflows/" 2>/dev/null || true
    echo "  ✓ .github/workflows/sync-notion.yml 복사 완료"

    # GEMINI.md 복사 (Gemini CLI 프로젝트 컨텍스트)
    cp "${INFRA_DIR}/GEMINI.md" "${REPO_DIR}/GEMINI.md" 2>/dev/null || true
    echo "  ✓ GEMINI.md 복사 완료"
  fi
  echo ""
done

echo "=== 배포 완료 ==="
if [ "$DRY_RUN" = false ]; then
  echo ""
  echo "다음 단계:"
  echo "  1. 각 레포에서 변경사항 확인: git status"
  echo "  2. 커밋 & push: git add .claude .github && git commit -m 'chore: update claude config from shared-infra'"
  echo ""
  echo "팁: 이 스크립트를 shared-infra가 업데이트될 때마다 실행하세요."
fi
