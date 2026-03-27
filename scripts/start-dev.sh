#!/bin/bash
# ============================================================
# 매일 개발 시작용 스크립트
# ============================================================
# DB + 선택한 앱들을 한 번에 띄웁니다.
#
# 사용법:
#   ./start-dev.sh                # 대화형 선택
#   ./start-dev.sh --all          # 전체 (DB + 백엔드 5개 + 프론트 1개)
#   ./start-dev.sh --backend      # DB + 백엔드 5개
#   ./start-dev.sh --frontend     # 프론트엔드 2개 (chat + admin)
#   ./start-dev.sh 1,3,6          # 번호로 선택
#
# 종료:
#   ./start-dev.sh --stop         # 전체 중지
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$INFRA_DIR")"

# ── 앱 정의: (이름, 디렉토리, 실행명령, 포트) ──
declare -A APP_CMD APP_PORT APP_DIR

APP_DIR[backend-auth]="${PARENT_DIR}/backend-auth"
APP_CMD[backend-auth]="uv run python3 main.py"
APP_PORT[backend-auth]="8001"

APP_DIR[backend-base]="${PARENT_DIR}/backend-base"
APP_CMD[backend-base]="uv run python3 main.py"
APP_PORT[backend-base]="8002"

APP_DIR[backend-chat]="${PARENT_DIR}/backend-chat"
APP_CMD[backend-chat]="uv run python3 main.py"
APP_PORT[backend-chat]="8003"

APP_DIR[backend-llm-gateway]="${PARENT_DIR}/backend-llm-gateway"
APP_CMD[backend-llm-gateway]="uv run python3 main.py"
APP_PORT[backend-llm-gateway]="8080"

APP_DIR[backend-mcp]="${PARENT_DIR}/backend-mcp"
APP_CMD[backend-mcp]="uv run python3 server_sse.py"
APP_PORT[backend-mcp]="8084"

APP_DIR[frontend-chat]="${PARENT_DIR}/frontend/chat"
APP_CMD[frontend-chat]="pnpm dev"
APP_PORT[frontend-chat]="3000"

APP_DIR[frontend-admin]="${PARENT_DIR}/frontend/admin"
APP_CMD[frontend-admin]="pnpm dev"
APP_PORT[frontend-admin]="3001"

ALL_APPS=("backend-auth" "backend-base" "backend-chat" "backend-llm-gateway" "backend-mcp" "frontend-chat" "frontend-admin")
BACKEND_APPS=("backend-auth" "backend-base" "backend-chat" "backend-llm-gateway" "backend-mcp")
FRONTEND_APPS=("frontend")

LOG_DIR="${INFRA_DIR}/.dev-logs"
PID_FILE="${INFRA_DIR}/.dev-pids"

# ── 유틸 함수 ──
info()    { echo -e "${BLUE}ℹ ${NC}$1"; }
success() { echo -e "${GREEN}✅ ${NC}$1"; }
warn()    { echo -e "${YELLOW}⚠️  ${NC}$1"; }
error()   { echo -e "${RED}❌ ${NC}$1"; }

# ============================================================
# 전체 중지
# ============================================================
stop_all() {
  echo ""
  echo -e "${CYAN}══════════════════════════════════════${NC}"
  echo -e "${CYAN}  개발 서버 전체 중지${NC}"
  echo -e "${CYAN}══════════════════════════════════════${NC}"
  echo ""

  if [ -f "$PID_FILE" ]; then
    while IFS='=' read -r app pid; do
      if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        # 자식 프로세스도 종료
        pkill -P "$pid" 2>/dev/null || true
        success "${app} (PID: ${pid}) 중지"
      else
        info "${app} (PID: ${pid}) 이미 종료됨"
      fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
  else
    info "실행 중인 앱이 없습니다."
  fi

  # DB 중지 여부
  local compose_file="${INFRA_DIR}/docker-compose.dev.yml"
  if docker compose -f "$compose_file" ps --status running 2>/dev/null | grep -q "dev-postgres"; then
    echo ""
    echo -n "  DB도 중지할까요? (y/N): "
    read -r DB_STOP
    if [[ "$DB_STOP" =~ ^[Yy] ]]; then
      docker compose -f "$compose_file" down 2>/dev/null
      success "PostgreSQL + Redis 중지"
    fi
  fi

  echo ""
  success "전체 중지 완료"
  exit 0
}

# ============================================================
# 상태 확인
# ============================================================
show_status() {
  echo ""
  echo -e "${CYAN}══════════════════════════════════════${NC}"
  echo -e "${CYAN}  개발 서버 상태${NC}"
  echo -e "${CYAN}══════════════════════════════════════${NC}"
  echo ""

  # DB 상태
  local compose_file="${INFRA_DIR}/docker-compose.dev.yml"
  if docker compose -f "$compose_file" ps --status running 2>/dev/null | grep -q "dev-postgres"; then
    echo -e "  ${GREEN}●${NC} PostgreSQL    localhost:5432"
  else
    echo -e "  ${RED}●${NC} PostgreSQL    (중지됨)"
  fi
  if docker compose -f "$compose_file" ps --status running 2>/dev/null | grep -q "dev-redis"; then
    echo -e "  ${GREEN}●${NC} Redis         localhost:6379"
  else
    echo -e "  ${RED}●${NC} Redis         (중지됨)"
  fi

  echo ""

  # 앱 상태
  if [ -f "$PID_FILE" ]; then
    while IFS='=' read -r app pid; do
      local port="${APP_PORT[$app]}"
      if kill -0 "$pid" 2>/dev/null; then
        echo -e "  ${GREEN}●${NC} ${app}    localhost:${port}  (PID: ${pid})"
      else
        echo -e "  ${RED}●${NC} ${app}    localhost:${port}  (종료됨)"
      fi
    done < "$PID_FILE"
  else
    for app in "${ALL_APPS[@]}"; do
      local port="${APP_PORT[$app]}"
      echo -e "  ${RED}●${NC} ${app}    localhost:${port}  (미시작)"
    done
  fi

  echo ""
  exit 0
}

# ============================================================
# 앱 선택
# ============================================================
select_apps() {
  local arg="$1"

  if [ "$arg" = "--all" ]; then
    SELECTED_APPS=("${ALL_APPS[@]}")
    return
  elif [ "$arg" = "--backend" ]; then
    SELECTED_APPS=("${BACKEND_APPS[@]}")
    return
  elif [ "$arg" = "--frontend" ]; then
    SELECTED_APPS=("${FRONTEND_APPS[@]}")
    return
  elif [[ "$arg" =~ ^[0-9,]+$ ]]; then
    # 번호로 선택
    SELECTED_APPS=()
    IFS=',' read -ra NUMS <<< "$arg"
    for num in "${NUMS[@]}"; do
      num=$(echo "$num" | tr -d ' ')
      case "$num" in
        1) SELECTED_APPS+=("backend-auth") ;;
        2) SELECTED_APPS+=("backend-base") ;;
        3) SELECTED_APPS+=("backend-chat") ;;
        4) SELECTED_APPS+=("backend-llm-gateway") ;;
        5) SELECTED_APPS+=("backend-mcp") ;;
        6) SELECTED_APPS+=("frontend") ;;
      esac
    done
    return
  fi

  # 대화형 선택
  echo ""
  echo "  [0] 전체 (DB + 백엔드 5개 + 프론트 1개)"
  echo ""
  echo "  ── 백엔드 ──"
  echo "  [1] backend-auth          :8001"
  echo "  [2] backend-base          :8002"
  echo "  [3] backend-chat          :8003"
  echo "  [4] backend-llm-gateway   :8080"
  echo "  [5] backend-mcp           :8084  (SSE)"
  echo ""
  echo "  ── 프론트엔드 (frontend 레포) ──"
  echo "  [6] frontend-chat         :3000"
  echo "  [7] frontend-admin        :3001"
  echo ""
  echo -n "  선택 (쉼표 구분, 예: 1,3,6): "
  read -r SELECTION

  if [ "$SELECTION" = "0" ]; then
    SELECTED_APPS=("${ALL_APPS[@]}")
  else
    SELECTED_APPS=()
    IFS=',' read -ra NUMS <<< "$SELECTION"
    for num in "${NUMS[@]}"; do
      num=$(echo "$num" | tr -d ' ')
      case "$num" in
        1) SELECTED_APPS+=("backend-auth") ;;
        2) SELECTED_APPS+=("backend-base") ;;
        3) SELECTED_APPS+=("backend-chat") ;;
        4) SELECTED_APPS+=("backend-llm-gateway") ;;
        5) SELECTED_APPS+=("backend-mcp") ;;
        6) SELECTED_APPS+=("frontend") ;;
      esac
    done
  fi
}

# ============================================================
# DB 기동
# ============================================================
start_db() {
  local compose_file="${INFRA_DIR}/docker-compose.dev.yml"

  if ! command -v docker &>/dev/null || ! docker info &>/dev/null 2>&1; then
    warn "Docker가 실행 중이 아닙니다 — DB를 수동으로 준비하세요."
    return
  fi

  if docker compose -f "$compose_file" ps --status running 2>/dev/null | grep -q "dev-postgres"; then
    success "PostgreSQL 이미 실행 중"
    success "Redis 이미 실행 중"
    return
  fi

  info "PostgreSQL + Redis 시작 중..."
  docker compose -f "$compose_file" up -d 2>&1 | tail -3

  # 헬스체크 대기
  local waited=0
  while [ $waited -lt 20 ]; do
    if docker exec dev-postgres pg_isready -U user -d dev &>/dev/null 2>&1; then
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done

  if [ $waited -lt 20 ]; then
    success "PostgreSQL 준비 완료 (:5432)"
    success "Redis 준비 완료 (:6379)"
  else
    warn "DB 시작 지연 — 로그 확인: docker compose -f $compose_file logs"
  fi
}

# ============================================================
# 앱 기동
# ============================================================
start_app() {
  local app=$1
  local dir="${APP_DIR[$app]}"
  local cmd="${APP_CMD[$app]}"
  local port="${APP_PORT[$app]}"

  if [ ! -d "$dir" ]; then
    warn "${app}: 디렉토리 없음 (${dir}) — 건너뜀"
    return
  fi

  # 이미 해당 포트가 사용 중인지 확인
  if lsof -i ":${port}" &>/dev/null 2>&1 || ss -tlnp 2>/dev/null | grep -q ":${port} "; then
    warn "${app}: 포트 ${port} 이미 사용 중 — 건너뜀"
    return
  fi

  mkdir -p "$LOG_DIR"
  local log_file="${LOG_DIR}/${app}.log"

  info "${app} 시작 중... (포트: ${port})"
  cd "$dir"

  # 백그라운드 실행, 로그 파일로 출력
  nohup $cmd > "$log_file" 2>&1 &
  local pid=$!

  # PID 기록
  echo "${app}=${pid}" >> "$PID_FILE"

  # 잠시 대기 후 프로세스 살아있는지 확인
  sleep 1
  if kill -0 "$pid" 2>/dev/null; then
    success "${app} 시작 완료 (PID: ${pid}, 포트: ${port})"
    info "  로그: tail -f ${log_file}"
  else
    error "${app} 시작 실패 — 로그 확인: cat ${log_file}"
  fi
}

# ============================================================
# MAIN
# ============================================================
main() {
  # 옵션 처리
  case "$1" in
    --stop)   stop_all ;;
    --status) show_status ;;
  esac

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║      개발 서버 시작 (start-dev)      ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"

  select_apps "$1"

  if [ ${#SELECTED_APPS[@]} -eq 0 ]; then
    error "선택된 앱이 없습니다."
    exit 1
  fi

  echo ""
  info "시작할 앱: ${SELECTED_APPS[*]}"
  echo ""

  # 기존 PID 파일 정리
  if [ -f "$PID_FILE" ]; then
    warn "이전 실행 기록이 있습니다. 기존 프로세스를 먼저 종료합니다."
    stop_all_quiet
  fi
  : > "$PID_FILE"  # PID 파일 초기화

  # 백엔드가 포함되면 DB 먼저 띄우기
  local need_db=false
  for app in "${SELECTED_APPS[@]}"; do
    [[ "$app" == backend-* ]] && need_db=true
  done

  if $need_db; then
    echo -e "\n${CYAN}── DB 기동 ──${NC}"
    start_db
  fi

  # 앱 순차 기동
  echo -e "\n${CYAN}── 앱 기동 ──${NC}"
  for app in "${SELECTED_APPS[@]}"; do
    start_app "$app"
  done

  # 요약
  echo ""
  echo -e "${CYAN}══════════════════════════════════════${NC}"
  echo -e "${CYAN}  실행 중인 서비스${NC}"
  echo -e "${CYAN}══════════════════════════════════════${NC}"
  echo ""

  if $need_db; then
    echo -e "  ${GREEN}●${NC} PostgreSQL       localhost:5432"
    echo -e "  ${GREEN}●${NC} Redis            localhost:6379"
  fi

  for app in "${SELECTED_APPS[@]}"; do
    local port="${APP_PORT[$app]}"
    echo -e "  ${GREEN}●${NC} ${app}    localhost:${port}"
  done

  echo ""
  echo -e "  ${YELLOW}관리 명령:${NC}"
  echo "  ./scripts/start-dev.sh --status    # 상태 확인"
  echo "  ./scripts/start-dev.sh --stop      # 전체 중지"
  echo "  tail -f .dev-logs/<앱이름>.log      # 로그 보기"
  echo ""
}

# 조용히 기존 프로세스 종료 (재시작 시 사용)
stop_all_quiet() {
  if [ -f "$PID_FILE" ]; then
    while IFS='=' read -r app pid; do
      if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        pkill -P "$pid" 2>/dev/null || true
      fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
  fi
}

main "$@"
