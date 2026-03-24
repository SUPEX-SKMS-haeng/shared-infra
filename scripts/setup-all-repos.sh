#!/bin/bash
# 모든 앱 레포에 서브모듈 + 심볼릭 링크를 한번에 셋업
#
# 사용법: cd ~/Workspace/GitHub/shared-infra && ./scripts/setup-all-repos.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$INFRA_DIR")"

REPOS=(
  "backend-auth"
  "backend-base"
  "backend-chat"
  "backend-llm-gateway"
  "backend-mcp"
  "frontend-admin"
  "frontend-chat"
  "frontend-shared"
)

echo "=========================================="
echo " 전체 레포 셋업 (서브모듈 + 심볼릭 링크)"
echo "=========================================="
echo ""

for repo in "${REPOS[@]}"; do
  REPO_DIR="${PARENT_DIR}/${repo}"

  if [ ! -d "$REPO_DIR" ]; then
    echo "⚠️  ${repo}: 디렉토리 없음, 건너뜀"
    echo ""
    continue
  fi

  cd "$REPO_DIR"
  "$SCRIPT_DIR/setup-repo.sh"
  echo ""
done

echo "=========================================="
echo " 전체 셋업 완료!"
echo "=========================================="
echo ""
echo "각 레포에서 커밋 & push:"
echo '  for repo in '"${REPOS[*]}"'; do'
echo '    cd '"$PARENT_DIR"'/$repo'
echo '    git add -A && git commit -m "chore: link shared-infra via symlinks" && git push'
echo '  done'
