#!/bin/bash
# ============================================================
# 개발자 온보딩 자동화 스크립트
# ============================================================
# 새 개발자가 프로젝트에 참여할 때, 원하는 앱을 선택해서
# 클론 → 서브모듈 → 가상환경 → 의존성 → .env → 실행 확인까지 한 번에 처리합니다.
#
# 사용법:
#   curl -sL <raw-url> | bash           # 또는
#   ./developer-setup.sh                 # shared-infra를 이미 클론한 경우
#
# 옵션:
#   ./developer-setup.sh --all           # 모든 앱 클론
#   ./developer-setup.sh --backend       # 백엔드만
#   ./developer-setup.sh --frontend      # 프론트엔드만
# ============================================================

set -e

# ── 색상 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── GitHub Org ──
ORG="agent-template-apps"
GITHUB_BASE="https://github.com/${ORG}"

# ── 앱 목록 ──
BACKEND_REPOS=("backend-auth" "backend-base" "backend-chat" "backend-llm-gateway" "backend-mcp" "backend-agent")
FRONTEND_REPOS=("frontend")
ALL_REPOS=("${BACKEND_REPOS[@]}" "${FRONTEND_REPOS[@]}")

# ── 유틸 함수 ──
info()    { echo -e "${BLUE}ℹ ${NC}$1"; }
success() { echo -e "${GREEN}✅ ${NC}$1"; }
warn()    { echo -e "${YELLOW}⚠️  ${NC}$1"; }
error()   { echo -e "${RED}❌ ${NC}$1"; }
header()  { echo -e "\n${CYAN}══════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}══════════════════════════════════════${NC}"; }

# ============================================================
# 0. 사전 요구사항 체크
# ============================================================
check_prerequisites() {
  header "사전 요구사항 확인"

  local missing=()

  # git
  if command -v git &>/dev/null; then
    success "git $(git --version | awk '{print $3}')"
  else
    missing+=("git")
  fi

  # gh (GitHub CLI) - 선택사항
  if command -v gh &>/dev/null; then
    success "gh $(gh --version | head -1 | awk '{print $3}')"
  else
    warn "gh (GitHub CLI) 미설치 — HTTPS 클론으로 진행합니다"
  fi

  # Python
  if command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 --version | awk '{print $2}')
    PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
    PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
    if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 12 ]; then
      success "python3 ${PY_VERSION} (>= 3.12 ✓)"
    else
      error "python3 ${PY_VERSION} — 3.12 이상 필요"
      missing+=("python3>=3.12")
    fi
  else
    missing+=("python3")
  fi

  # uv (Python 패키지 매니저)
  if command -v uv &>/dev/null; then
    success "uv $(uv --version 2>/dev/null | awk '{print $2}')"
  else
    warn "uv 미설치 — 자동 설치합니다"
    info "설치 중: curl -LsSf https://astral.sh/uv/install.sh | sh"
    curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null
    export PATH="$HOME/.local/bin:$PATH"
    if command -v uv &>/dev/null; then
      success "uv 설치 완료"
    else
      missing+=("uv")
    fi
  fi

  # Node.js
  if command -v node &>/dev/null; then
    NODE_VERSION=$(node --version | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    if [ "$NODE_MAJOR" -ge 20 ]; then
      success "node ${NODE_VERSION} (>= 20 ✓)"
    else
      warn "node ${NODE_VERSION} — 20 이상 권장"
    fi
  else
    warn "node 미설치 — 프론트엔드 앱 실행 불가"
  fi

  # pnpm
  if command -v pnpm &>/dev/null; then
    success "pnpm $(pnpm --version)"
  else
    if command -v node &>/dev/null; then
      warn "pnpm 미설치 — 자동 설치합니다"
      npm install -g pnpm 2>/dev/null && success "pnpm 설치 완료" || missing+=("pnpm")
    fi
  fi

  # pre-commit
  if command -v pre-commit &>/dev/null; then
    success "pre-commit $(pre-commit --version | awk '{print $2}')"
  else
    warn "pre-commit 미설치 — 백엔드 셋업 시 자동 설치합니다"
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    echo ""
    error "누락된 필수 도구: ${missing[*]}"
    error "위 도구를 설치한 후 다시 실행해주세요."
    exit 1
  fi

  echo ""
  success "사전 요구사항 확인 완료"
}

# ============================================================
# 1. 워크스페이스 디렉토리 결정
# ============================================================
setup_workspace() {
  header "워크스페이스 설정"

  # 기본 경로 제안
  DEFAULT_DIR="$HOME/Workspace/GitHub"

  echo -e "프로젝트를 클론할 디렉토리를 입력하세요."
  echo -e "  기본값: ${CYAN}${DEFAULT_DIR}${NC}"
  echo -n "  경로 (Enter=기본값): "
  read -r WORKSPACE_DIR

  if [ -z "$WORKSPACE_DIR" ]; then
    WORKSPACE_DIR="$DEFAULT_DIR"
  fi

  # ~ 확장
  WORKSPACE_DIR="${WORKSPACE_DIR/#\~/$HOME}"

  mkdir -p "$WORKSPACE_DIR"
  success "워크스페이스: ${WORKSPACE_DIR}"
}

# ============================================================
# 2. 앱 선택
# ============================================================
select_repos() {
  header "클론할 앱 선택"

  # 커맨드라인 옵션 처리
  if [ "$1" = "--all" ]; then
    SELECTED_REPOS=("${ALL_REPOS[@]}")
    info "모든 앱 선택됨 (--all)"
    return
  elif [ "$1" = "--backend" ]; then
    SELECTED_REPOS=("${BACKEND_REPOS[@]}")
    info "백엔드만 선택됨 (--backend)"
    return
  elif [ "$1" = "--frontend" ]; then
    SELECTED_REPOS=("${FRONTEND_REPOS[@]}")
    info "프론트엔드만 선택됨 (--frontend)"
    return
  fi

  echo ""
  echo "  [0] 전체 (7개 모두)"
  echo ""
  echo "  ── 백엔드 ──"
  echo "  [1] backend-auth          인증/JWT/사용자관리"
  echo "  [2] backend-base          기본 API/조직관리"
  echo "  [3] backend-chat          채팅/LLM 스트리밍"
  echo "  [4] backend-llm-gateway   LLM 라우팅/프롬프트관리"
  echo "  [5] backend-mcp           MCP 도구/벡터DB"
  echo "  [6] backend-agent         RAG 에이전트/백그라운드 작업"
  echo ""
  echo "  ── 프론트엔드 ──"
  echo "  [7] frontend              프론트엔드 (관리자+채팅)"
  echo ""
  echo -n "  선택 (쉼표로 구분, 예: 1,3,7): "
  read -r SELECTION

  SELECTED_REPOS=()

  if [ "$SELECTION" = "0" ]; then
    SELECTED_REPOS=("${ALL_REPOS[@]}")
  else
    IFS=',' read -ra NUMS <<< "$SELECTION"
    for num in "${NUMS[@]}"; do
      num=$(echo "$num" | tr -d ' ')
      case "$num" in
        1) SELECTED_REPOS+=("backend-auth") ;;
        2) SELECTED_REPOS+=("backend-base") ;;
        3) SELECTED_REPOS+=("backend-chat") ;;
        4) SELECTED_REPOS+=("backend-llm-gateway") ;;
        5) SELECTED_REPOS+=("backend-mcp") ;;
        6) SELECTED_REPOS+=("backend-agent") ;;
        7) SELECTED_REPOS+=("frontend") ;;
        *) warn "알 수 없는 번호: $num (무시)" ;;
      esac
    done
  fi

  if [ ${#SELECTED_REPOS[@]} -eq 0 ]; then
    error "선택된 앱이 없습니다."
    exit 1
  fi

  echo ""
  info "선택된 앱: ${SELECTED_REPOS[*]}"
}

# ============================================================
# 3. shared-infra 클론
# ============================================================
clone_shared_infra() {
  header "shared-infra 클론"

  if [ -d "${WORKSPACE_DIR}/shared-infra/.git" ]; then
    info "shared-infra 이미 존재 — 최신으로 pull"
    cd "${WORKSPACE_DIR}/shared-infra"
    git pull --quiet 2>/dev/null || warn "shared-infra pull 실패 (트래킹 브랜치 없음 등) — 기존 로컬 상태로 진행"
    success "shared-infra 확인 완료"
  else
    info "shared-infra 클론 중..."
    git clone --quiet "${GITHUB_BASE}/shared-infra.git" "${WORKSPACE_DIR}/shared-infra"
    success "shared-infra 클론 완료"
  fi
}

# ============================================================
# 4. 앱 레포 클론 + 서브모듈
# ============================================================
clone_app_repo() {
  local repo=$1

  if [ -d "${WORKSPACE_DIR}/${repo}/.git" ]; then
    info "${repo}: 이미 존재 — pull"
    cd "${WORKSPACE_DIR}/${repo}"
    git pull --quiet 2>/dev/null || warn "${repo}: pull 실패 — 기존 로컬 상태로 진행"
    git submodule update --init --recursive --quiet 2>/dev/null || true
  else
    info "${repo}: 클론 중..."
    git clone --recurse-submodules --quiet "${GITHUB_BASE}/${repo}.git" "${WORKSPACE_DIR}/${repo}"
  fi

  success "${repo}: 클론 완료"
}

# ============================================================
# 5. setup-repo.sh 실행 (서브모듈이 연결된 경우)
# ============================================================
run_setup_repo() {
  local repo=$1

  cd "${WORKSPACE_DIR}/${repo}"

  # 서브모듈이 아직 연결 안 된 경우 → 심볼릭 대신 직접 복사
  if [ ! -d "${WORKSPACE_DIR}/${repo}/infra/.claude" ]; then
    info "${repo}: 서브모듈 미연결 — shared-infra에서 직접 설정 복사"
    setup_without_submodule "$repo"
  else
    info "${repo}: setup-repo.sh 실행"
    bash "${WORKSPACE_DIR}/${repo}/infra/scripts/setup-repo.sh"
  fi
}

# ── 서브모듈 없이 직접 복사하는 fallback ──
setup_without_submodule() {
  local repo=$1
  local base="${WORKSPACE_DIR}/${repo}"
  local infra="${WORKSPACE_DIR}/shared-infra"

  # .claude/ 디렉토리 (복사)
  mkdir -p "${base}/.claude"
  if [ -d "${infra}/.claude/commands" ]; then
    rm -rf "${base}/.claude/commands" 2>/dev/null
    cp -r "${infra}/.claude/commands" "${base}/.claude/commands"
  fi
  if [ -d "${infra}/.claude/agents" ]; then
    rm -rf "${base}/.claude/agents" 2>/dev/null
    cp -r "${infra}/.claude/agents" "${base}/.claude/agents"
  fi

  # .github/ISSUE_TEMPLATE
  mkdir -p "${base}/.github"
  if [ -d "${infra}/.github/ISSUE_TEMPLATE" ]; then
    rm -rf "${base}/.github/ISSUE_TEMPLATE" 2>/dev/null
    cp -r "${infra}/.github/ISSUE_TEMPLATE" "${base}/.github/ISSUE_TEMPLATE"
  fi

  # .github/workflows
  mkdir -p "${base}/.github/workflows"
  if [ -f "${infra}/.github/workflows/sync-notion.yml" ]; then
    cp "${infra}/.github/workflows/sync-notion.yml" "${base}/.github/workflows/"
  fi

  # .editorconfig
  [ -f "${infra}/configs/.editorconfig" ] && cp "${infra}/configs/.editorconfig" "${base}/.editorconfig"

  # 타입별 설정
  if [[ "$repo" == backend-* ]]; then
    [ -f "${infra}/configs/ruff.toml" ] && cp "${infra}/configs/ruff.toml" "${base}/ruff.toml"
    [ -f "${infra}/configs/.pre-commit-config-backend.yaml" ] && cp "${infra}/configs/.pre-commit-config-backend.yaml" "${base}/.pre-commit-config.yaml"
    mkdir -p "${base}/.vscode"
    [ -f "${infra}/configs/vscode-backend.json" ] && cp "${infra}/configs/vscode-backend.json" "${base}/.vscode/settings.json"
    [ -f "${infra}/configs/vscode-extensions-backend.json" ] && cp "${infra}/configs/vscode-extensions-backend.json" "${base}/.vscode/extensions.json"
  elif [[ "$repo" == frontend* ]]; then
    [ -f "${infra}/configs/.prettierrc" ] && cp "${infra}/configs/.prettierrc" "${base}/.prettierrc"
    [ -f "${infra}/configs/.pre-commit-config-frontend.yaml" ] && cp "${infra}/configs/.pre-commit-config-frontend.yaml" "${base}/.pre-commit-config.yaml"
    mkdir -p "${base}/.vscode"
    [ -f "${infra}/configs/vscode-frontend.json" ] && cp "${infra}/configs/vscode-frontend.json" "${base}/.vscode/settings.json"
    [ -f "${infra}/configs/vscode-extensions-frontend.json" ] && cp "${infra}/configs/vscode-extensions-frontend.json" "${base}/.vscode/extensions.json"
  fi

  # llm-review.yml 생성
  local app_type=""
  [[ "$repo" == backend-* ]] && app_type="backend"
  [[ "$repo" == frontend* ]] && app_type="frontend"
  if [ -n "$app_type" ]; then
    cat > "${base}/.github/workflows/llm-review.yml" << YAML_EOF
name: LLM Code Review
on:
  pull_request:
    types: [opened, synchronize]
jobs:
  review:
    uses: ${ORG}/shared-infra/.github/workflows/gemini-review-reusable.yml@main
    with:
      app_type: ${app_type}
      app_name: ${repo}
    secrets: inherit
YAML_EOF
  fi

  success "${repo}: 설정 복사 완료 (서브모듈 미사용 모드)"
}

# ============================================================
# 5.5 로컬 DB 기동 (PostgreSQL + Redis)
# ============================================================
start_local_db() {
  header "로컬 DB 기동 (PostgreSQL + Redis)"

  # Docker 확인
  if ! command -v docker &>/dev/null; then
    warn "Docker가 설치되어 있지 않습니다."
    warn "로컬 DB를 수동으로 준비하거나 Docker를 설치해주세요."
    warn "  macOS: brew install --cask docker"
    warn "  Windows: https://docs.docker.com/desktop/install/windows-install/"
    DB_STARTED=false
    return
  fi

  # Docker 데몬 실행 확인
  if ! docker info &>/dev/null 2>&1; then
    warn "Docker 데몬이 실행 중이 아닙니다."
    warn "Docker Desktop을 실행한 후 다시 시도해주세요."
    DB_STARTED=false
    return
  fi

  local compose_file="${WORKSPACE_DIR}/shared-infra/docker-compose.dev.yml"

  if [ ! -f "$compose_file" ]; then
    warn "docker-compose.dev.yml 없음 — DB 자동 기동 건너뜀"
    DB_STARTED=false
    return
  fi

  # 이미 실행 중인지 확인
  if docker compose -f "$compose_file" ps --status running 2>/dev/null | grep -q "dev-postgres"; then
    success "PostgreSQL 이미 실행 중 (dev-postgres)"
    if docker compose -f "$compose_file" ps --status running 2>/dev/null | grep -q "dev-redis"; then
      success "Redis 이미 실행 중 (dev-redis)"
    fi
    DB_STARTED=true
    return
  fi

  echo -n "  로컬 DB를 Docker로 띄울까요? (Y/n): "
  read -r DB_CONFIRM
  if [[ "$DB_CONFIRM" =~ ^[Nn] ]]; then
    info "DB 기동 건너뜀 — 수동으로 준비해주세요."
    DB_STARTED=false
    return
  fi

  info "PostgreSQL + Redis 시작 중..."
  docker compose -f "$compose_file" up -d 2>&1 | tail -5

  # 헬스체크 대기
  info "DB 준비 대기 중..."
  local max_wait=30
  local waited=0
  while [ $waited -lt $max_wait ]; do
    if docker compose -f "$compose_file" ps --status running 2>/dev/null | grep -q "dev-postgres"; then
      # PostgreSQL 접속 가능 여부 확인
      if docker exec dev-postgres pg_isready -U user -d dev &>/dev/null; then
        break
      fi
    fi
    sleep 2
    waited=$((waited + 2))
    echo -n "."
  done
  echo ""

  if [ $waited -ge $max_wait ]; then
    warn "DB 시작 타임아웃 (${max_wait}초) — 수동 확인 필요"
    warn "  docker compose -f ${compose_file} logs"
    DB_STARTED=false
    return
  fi

  success "PostgreSQL 준비 완료 (localhost:5432, DB: dev, User: user)"
  success "Redis 준비 완료 (localhost:6379)"
  echo ""
  info "접속 정보 (.env.example 기본값과 동일):"
  echo "  DB_HOST=127.0.0.1  DB_PORT=5432  DB_NAME=dev"
  echo "  DB_USER=user       DB_PASSWORD=password"
  echo "  REDIS_HOST=127.0.0.1  REDIS_PORT=6379"

  DB_STARTED=true
}

# ============================================================
# 6. 백엔드 환경 셋업 (venv + 의존성 + .env)
# ============================================================
setup_backend() {
  local repo=$1
  local base="${WORKSPACE_DIR}/${repo}"

  header "${repo} — Python 환경 셋업"
  cd "$base"

  # 6-1. uv로 가상환경 + 의존성 설치
  info "가상환경 생성 + 의존성 설치 (uv sync)..."
  uv sync 2>&1 | tail -3
  success "의존성 설치 완료"

  # 6-2. .env 생성
  if [ ! -f "${base}/.env" ]; then
    if [ -f "${base}/.env.example" ]; then
      cp "${base}/.env.example" "${base}/.env"
      success ".env 생성 (.env.example 복사)"
      if [ "$DB_STARTED" = true ]; then
        info "→ 로컬 DB가 실행 중이므로 기본값으로 바로 사용 가능합니다."
        info "→ Azure OpenAI 등 외부 API 키만 필요 시 수정하세요."
      else
        warn "→ .env 파일의 DB 접속 정보를 실제 환경에 맞게 수정하세요!"
      fi
    else
      warn ".env.example 없음 — .env 수동 생성 필요"
    fi
  else
    info ".env 이미 존재 — 건너뜀"
  fi

  # 6-3. pre-commit 설치
  if [ -f "${base}/.pre-commit-config.yaml" ]; then
    if command -v pre-commit &>/dev/null; then
      pre-commit install --allow-missing-config 2>/dev/null
      success "pre-commit hook 설치"
    else
      info "pre-commit 설치 시도..."
      uv run pip install pre-commit 2>/dev/null
      if uv run pre-commit install --allow-missing-config 2>/dev/null; then
        success "pre-commit hook 설치"
      else
        warn "pre-commit 설치 실패 — 나중에 수동 설치: pip install pre-commit && pre-commit install"
      fi
    fi
  fi

  # 6-4. 실행 테스트 (import만 확인)
  info "앱 import 테스트..."
  if uv run python3 -c "from app.main import app; print('FastAPI app loaded OK')" 2>/dev/null; then
    success "${repo}: import 테스트 통과"
  else
    warn "${repo}: import 실패 — .env 설정 또는 DB 연결을 확인하세요"
  fi
}

# ============================================================
# 7. 프론트엔드 환경 셋업 (pnpm + 의존성)
# ============================================================
setup_frontend() {
  local repo=$1
  local base="${WORKSPACE_DIR}/${repo}"

  header "${repo} — Node.js 환경 셋업"
  cd "$base"

  if ! command -v pnpm &>/dev/null; then
    error "pnpm 미설치 — 프론트엔드 셋업 건너뜀"
    return
  fi

  # 7-1. 의존성 설치 (admin, chat 각각)
  for app_dir in admin chat; do
    if [ -d "${base}/${app_dir}" ] && [ -f "${base}/${app_dir}/package.json" ]; then
      info "${app_dir}/ — pnpm install..."
      cd "${base}/${app_dir}"
      pnpm install --frozen-lockfile 2>&1 | tail -3
      success "${app_dir}: 의존성 설치 완료"
    fi
  done

  # 7-2. pre-commit 설치 (Python 필요)
  cd "$base"
  if [ -f "${base}/.pre-commit-config.yaml" ] && command -v pre-commit &>/dev/null; then
    pre-commit install --allow-missing-config 2>/dev/null
    success "pre-commit hook 설치"
  fi

  # 7-3. 빌드 테스트 (admin)
  if [ -d "${base}/admin" ]; then
    cd "${base}/admin"
    info "빌드 테스트 (admin — pnpm build)..."
    if pnpm build 2>&1 | tail -3; then
      success "admin: 빌드 성공"
    else
      warn "admin: 빌드 실패 — 환경 설정을 확인하세요"
    fi
  fi
}

# ============================================================
# 8. 최종 요약
# ============================================================
print_summary() {
  header "셋업 완료 요약"

  echo ""
  echo -e "  📁 워크스페이스: ${CYAN}${WORKSPACE_DIR}${NC}"
  echo ""

  for repo in "${SELECTED_REPOS[@]}"; do
    local base="${WORKSPACE_DIR}/${repo}"
    if [ -d "${base}/.git" ]; then
      echo -e "  ${GREEN}✅${NC} ${repo}"
    else
      echo -e "  ${RED}❌${NC} ${repo}"
    fi
  done

  echo ""
  echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${YELLOW}다음 단계:${NC}"
  echo ""

  # 백엔드가 있으면
  local has_backend=false
  local has_frontend=false
  for repo in "${SELECTED_REPOS[@]}"; do
    [[ "$repo" == backend-* ]] && has_backend=true
    [[ "$repo" == frontend* ]] && has_frontend=true
  done

  if $has_backend; then
    echo -e "  ${CYAN}[백엔드 실행]${NC}"
    echo "  cd ${WORKSPACE_DIR}/backend-auth"
    echo "  uv run python3 main.py"
    echo ""
    echo -e "  ${CYAN}[로컬 DB 관리]${NC}"
    echo "  cd ${WORKSPACE_DIR}/shared-infra"
    echo "  docker compose -f docker-compose.dev.yml up -d     # DB 시작"
    echo "  docker compose -f docker-compose.dev.yml down       # DB 중지"
    echo "  docker compose -f docker-compose.dev.yml down -v    # DB 초기화 (데이터 삭제)"
    echo ""
  fi

  if $has_frontend; then
    echo -e "  ${CYAN}[프론트엔드 실행]${NC}"
    echo "  cd ${WORKSPACE_DIR}/frontend/chat && pnpm dev    # 채팅 UI (:3000)"
    echo "  cd ${WORKSPACE_DIR}/frontend/admin && pnpm dev   # 관리자 (:3001)"
    echo ""
  fi

  echo -e "  ${CYAN}[Claude Code 사용]${NC}"
  echo "  cd ${WORKSPACE_DIR}/<앱이름>"
  echo "  claude"
  echo "  > /start-task 42    # Issue 기반 개발 시작"
  echo ""

  echo -e "  ${CYAN}[shared-infra 업데이트 반영]${NC}"
  echo "  cd ${WORKSPACE_DIR}/<앱이름>"
  echo "  git submodule update --remote infra   # 서브모듈 사용 시"
  echo "  ./infra/scripts/setup-repo.sh"
  echo ""
}

# ============================================================
# MAIN
# ============================================================
main() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   Agent Template Apps — 개발환경 셋업    ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
  echo ""

  check_prerequisites
  setup_workspace
  select_repos "$1"

  # shared-infra 먼저
  clone_shared_infra

  # 각 앱 클론
  header "앱 레포 클론"
  for repo in "${SELECTED_REPOS[@]}"; do
    clone_app_repo "$repo"
  done

  # 각 앱 설정 배포
  header "설정 파일 배포"
  for repo in "${SELECTED_REPOS[@]}"; do
    run_setup_repo "$repo"
  done

  # 백엔드가 포함되어 있으면 로컬 DB 기동
  local has_any_backend=false
  for repo in "${SELECTED_REPOS[@]}"; do
    [[ "$repo" == backend-* ]] && has_any_backend=true
  done
  DB_STARTED=false
  if $has_any_backend; then
    start_local_db
  fi

  # 환경 셋업 (백엔드 → 프론트엔드 순)
  for repo in "${SELECTED_REPOS[@]}"; do
    if [[ "$repo" == backend-* ]]; then
      setup_backend "$repo"
    fi
  done

  for repo in "${SELECTED_REPOS[@]}"; do
    if [[ "$repo" == frontend* ]]; then
      setup_frontend "$repo"
    fi
  done

  # 요약
  print_summary
}

main "$@"
