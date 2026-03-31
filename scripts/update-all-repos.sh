#!/bin/bash
# 전체 앱 레포의 shared-infra 서브모듈을 최신으로 업데이트
#
# 사용법:
#   ./infra/scripts/update-all-repos.sh              # 기본 (~/Workspace/GitHub/agent-template-apps)
#   ./infra/scripts/update-all-repos.sh /path/to/org  # 경로 지정
#
# 또는 특정 레포만:
#   ./infra/scripts/update-all-repos.sh --repos "backend-auth frontend-chat"

set -e

# 기본 경로
DEFAULT_ORG_DIR="$HOME/Workspace/GitHub/agent-template-apps"
ORG_DIR="${1:-$DEFAULT_ORG_DIR}"

# --repos 옵션 처리
REPOS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repos)
      REPOS="$2"
      shift 2
      ;;
    *)
      ORG_DIR="$1"
      shift
      ;;
  esac
done

# 레포 목록 (지정 안 했으면 전체)
if [ -z "$REPOS" ]; then
  REPOS="backend-auth backend-base backend-chat backend-llm-gateway backend-mcp frontend-admin frontend-chat frontend-shared"
fi

echo "================================================"
echo "  shared-infra 서브모듈 일괄 업데이트"
echo "  경로: ${ORG_DIR}"
echo "================================================"
echo ""

SUCCESS=0
FAIL=0
SKIPPED=0

for repo in $REPOS; do
  REPO_DIR="${ORG_DIR}/${repo}"

  if [ ! -d "$REPO_DIR" ]; then
    echo "⏭️  ${repo} — 디렉토리 없음, 스킵"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "▶ ${repo}"
  cd "$REPO_DIR"

  # 서브모듈 업데이트
  if git submodule update --remote infra 2>/dev/null; then
    # 변경 확인
    if git diff --quiet infra 2>/dev/null; then
      echo "  ✓ 이미 최신"
    else
      echo "  ✓ infra 서브모듈 업데이트됨"
      # 서브모듈 변경 커밋
      git add infra
      git commit -m "chore: shared-infra 서브모듈 업데이트" 2>/dev/null || true
      echo "  ✓ 커밋 완료"
    fi
    SUCCESS=$((SUCCESS + 1))
  else
    echo "  ❌ 업데이트 실패"
    FAIL=$((FAIL + 1))
  fi

  echo ""
done

echo "================================================"
echo "  결과: 성공 ${SUCCESS} | 실패 ${FAIL} | 스킵 ${SKIPPED}"
echo "================================================"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
