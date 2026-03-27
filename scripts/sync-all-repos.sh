#!/bin/bash
# ============================================================
# shared-infra 업데이트를 전체 앱 레포에 반영
# ============================================================
# shared-infra에 변경(룰, 설정, 워크플로우 등)이 생겼을 때
# 모든 앱 레포의 서브모듈 + 설정 파일을 한 번에 갱신합니다.
#
# 사용법:
#   cd ~/Workspace/GitHub/shared-infra
#   ./scripts/sync-all-repos.sh
#
# 옵션:
#   --commit    갱신 후 각 레포에서 자동 커밋까지
#   --push      자동 커밋 + push까지
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$INFRA_DIR")"

REPOS=(
  "backend-auth"
  "backend-base"
  "backend-chat"
  "backend-llm-gateway"
  "backend-mcp"
  "frontend"
)

AUTO_COMMIT=false
AUTO_PUSH=false

if [ "$1" = "--commit" ]; then
  AUTO_COMMIT=true
elif [ "$1" = "--push" ]; then
  AUTO_COMMIT=true
  AUTO_PUSH=true
fi

echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}  shared-infra 변경사항 전체 레포 반영${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""

# shared-infra 최신 커밋 확인
cd "$INFRA_DIR"
LATEST_COMMIT=$(git log -1 --oneline)
echo -e "  shared-infra 최신: ${GREEN}${LATEST_COMMIT}${NC}"
echo ""

SUCCESS_REPOS=()
SKIP_REPOS=()
FAIL_REPOS=()

for repo in "${REPOS[@]}"; do
  REPO_DIR="${PARENT_DIR}/${repo}"

  if [ ! -d "$REPO_DIR/.git" ]; then
    echo -e "  ${YELLOW}⚠️  ${repo}: 디렉토리 없음 — 건너뜀${NC}"
    SKIP_REPOS+=("$repo")
    continue
  fi

  echo -e "  ${CYAN}▶ ${repo}${NC}"
  cd "$REPO_DIR"

  # 1. 서브모듈 업데이트
  if [ -f "$REPO_DIR/.gitmodules" ]; then
    git submodule update --remote infra --quiet 2>/dev/null
    echo -e "    ✅ 서브모듈 갱신"

    # 2. setup-repo.sh 실행 (설정 파일 재배포)
    if [ -f "$REPO_DIR/infra/scripts/setup-repo.sh" ]; then
      bash "$REPO_DIR/infra/scripts/setup-repo.sh" > /dev/null 2>&1
      echo -e "    ✅ 설정 파일 재배포"
    fi
  else
    # 서브모듈 미연결 → shared-infra에서 직접 복사
    echo -e "    ⚠️  서브모듈 미연결 — shared-infra에서 직접 복사"

    # .claude/ 복사
    mkdir -p "$REPO_DIR/.claude"
    [ -d "$INFRA_DIR/.claude/commands" ] && cp -r "$INFRA_DIR/.claude/commands" "$REPO_DIR/.claude/"
    [ -d "$INFRA_DIR/.claude/agents" ] && cp -r "$INFRA_DIR/.claude/agents" "$REPO_DIR/.claude/"

    # 설정 파일 복사
    [ -f "$INFRA_DIR/configs/.editorconfig" ] && cp "$INFRA_DIR/configs/.editorconfig" "$REPO_DIR/"
    if [[ "$repo" == backend-* ]]; then
      [ -f "$INFRA_DIR/configs/ruff.toml" ] && cp "$INFRA_DIR/configs/ruff.toml" "$REPO_DIR/"
      [ -f "$INFRA_DIR/configs/.pre-commit-config-backend.yaml" ] && cp "$INFRA_DIR/configs/.pre-commit-config-backend.yaml" "$REPO_DIR/.pre-commit-config.yaml"
      mkdir -p "$REPO_DIR/.vscode"
      [ -f "$INFRA_DIR/configs/vscode-backend.json" ] && cp "$INFRA_DIR/configs/vscode-backend.json" "$REPO_DIR/.vscode/settings.json"
      [ -f "$INFRA_DIR/configs/vscode-extensions-backend.json" ] && cp "$INFRA_DIR/configs/vscode-extensions-backend.json" "$REPO_DIR/.vscode/extensions.json"
    elif [[ "$repo" == frontend* ]]; then
      [ -f "$INFRA_DIR/configs/.prettierrc" ] && cp "$INFRA_DIR/configs/.prettierrc" "$REPO_DIR/"
      [ -f "$INFRA_DIR/configs/.pre-commit-config-frontend.yaml" ] && cp "$INFRA_DIR/configs/.pre-commit-config-frontend.yaml" "$REPO_DIR/.pre-commit-config.yaml"
      mkdir -p "$REPO_DIR/.vscode"
      [ -f "$INFRA_DIR/configs/vscode-frontend.json" ] && cp "$INFRA_DIR/configs/vscode-frontend.json" "$REPO_DIR/.vscode/settings.json"
      [ -f "$INFRA_DIR/configs/vscode-extensions-frontend.json" ] && cp "$INFRA_DIR/configs/vscode-extensions-frontend.json" "$REPO_DIR/.vscode/extensions.json"
    fi
    echo -e "    ✅ 설정 파일 직접 복사"
  fi

  # 3. 자동 커밋 (옵션)
  if $AUTO_COMMIT; then
    cd "$REPO_DIR"
    if [ -n "$(git status --porcelain)" ]; then
      git add -A
      git commit -m "chore: sync shared-infra settings

Updated: $(date +%Y-%m-%d)
shared-infra: ${LATEST_COMMIT}" --quiet
      echo -e "    ✅ 커밋 완료"

      if $AUTO_PUSH; then
        git push --quiet 2>/dev/null && echo -e "    ✅ push 완료" || echo -e "    ${YELLOW}⚠️  push 실패${NC}"
      fi
    else
      echo -e "    ℹ️  변경사항 없음 — 커밋 건너뜀"
    fi
  fi

  SUCCESS_REPOS+=("$repo")
  echo ""
done

# 요약
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}  완료 요약${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""
[ ${#SUCCESS_REPOS[@]} -gt 0 ] && echo -e "  ${GREEN}✅ 성공: ${SUCCESS_REPOS[*]}${NC}"
[ ${#SKIP_REPOS[@]} -gt 0 ] && echo -e "  ${YELLOW}⚠️  건너뜀: ${SKIP_REPOS[*]}${NC}"
[ ${#FAIL_REPOS[@]} -gt 0 ] && echo -e "  ${RED}❌ 실패: ${FAIL_REPOS[*]}${NC}"
echo ""

if ! $AUTO_COMMIT; then
  echo -e "  ${YELLOW}각 레포에서 변경사항을 확인 후 커밋하세요:${NC}"
  echo "  또는 자동 커밋: ./scripts/sync-all-repos.sh --commit"
  echo "  자동 커밋+push: ./scripts/sync-all-repos.sh --push"
  echo ""
fi
