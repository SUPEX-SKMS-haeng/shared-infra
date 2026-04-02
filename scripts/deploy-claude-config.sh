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
    echo "  [DRY] .claude/commands/*.md → ${repo}/.claude/commands/ (개별 symlink)"
    echo "  [DRY] .claude/agents/*.md → ${repo}/.claude/agents/ (개별 symlink)"
    echo "  [DRY] .claude/skills/*/ → ${repo}/.claude/skills/ (개별 symlink)"
    echo "  [DRY] .github/ISSUE_TEMPLATE/ → ${repo}/.github/ISSUE_TEMPLATE/"
    echo "  [DRY] .github/workflows/sync-notion.yml → ${repo}/.github/workflows/"

  else
    # 기존 디렉토리 symlink이 있으면 실제 디렉토리로 교체
    for subdir in commands agents skills; do
      if [ -L "${REPO_DIR}/.claude/${subdir}" ]; then
        rm "${REPO_DIR}/.claude/${subdir}"
      fi
    done

    # .claude/commands 개별 파일 symlink
    mkdir -p "${REPO_DIR}/.claude/commands"
    for file in "${INFRA_DIR}/.claude/commands/"*.md; do
      [ -f "$file" ] || continue
      name=$(basename "$file")
      target="../../infra/.claude/commands/${name}"
      ln -sf "$target" "${REPO_DIR}/.claude/commands/${name}"
    done
    echo "  ✓ .claude/commands/ 개별 symlink 완료"

    # .claude/agents 개별 파일 symlink
    mkdir -p "${REPO_DIR}/.claude/agents"
    for file in "${INFRA_DIR}/.claude/agents/"*.md; do
      [ -f "$file" ] || continue
      name=$(basename "$file")
      target="../../infra/.claude/agents/${name}"
      ln -sf "$target" "${REPO_DIR}/.claude/agents/${name}"
    done
    echo "  ✓ .claude/agents/ 개별 symlink 완료"

    # .claude/skills 서브디렉토리 단위 symlink (커스텀 보존)
    mkdir -p "${REPO_DIR}/.claude/skills"
    for dir in "${INFRA_DIR}/.claude/skills/"*/; do
      [ -d "$dir" ] || continue
      name=$(basename "$dir")
      target="../../infra/.claude/skills/${name}"
      if [ ! -e "${REPO_DIR}/.claude/skills/${name}" ]; then
        ln -sf "$target" "${REPO_DIR}/.claude/skills/${name}"
      fi
    done
    echo "  ✓ .claude/skills/ 개별 symlink 완료"

    # GitHub Issue 템플릿 복사
    mkdir -p "${REPO_DIR}/.github/ISSUE_TEMPLATE"
    cp -r "${INFRA_DIR}/.github/ISSUE_TEMPLATE/"* "${REPO_DIR}/.github/ISSUE_TEMPLATE/" 2>/dev/null || true
    echo "  ✓ .github/ISSUE_TEMPLATE/ 복사 완료"

    # Notion 동기화 워크플로우 복사
    mkdir -p "${REPO_DIR}/.github/workflows"
    cp "${INFRA_DIR}/.github/workflows/sync-notion.yml" "${REPO_DIR}/.github/workflows/" 2>/dev/null || true
    echo "  ✓ .github/workflows/sync-notion.yml 복사 완료"
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
