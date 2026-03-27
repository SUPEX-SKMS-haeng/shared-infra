# Agent Template Apps - 공통 개발 규칙

## 프로젝트 구조
- 멀티 레포: `agent-template-apps` GitHub Organization
- 백엔드: backend-auth, backend-base, backend-chat, backend-llm-gateway, backend-mcp
- 프론트엔드: frontend
- 공통 인프라: shared-infra (이 레포)
- 각 앱은 `infra/` 서브모듈로 shared-infra를 참조

## Git 워크플로우
- 브랜치 전략: `main` (운영), `develop` (개발)
- 기능 브랜치: `feat/{앱약어}/{이슈번호}-{설명}` (예: `feat/be-auth/12-add-oauth`)
- 버그 수정: `fix/{앱약어}/{이슈번호}-{설명}`
- 커밋 메시지: `type(scope): description` (Conventional Commits)
  - type: feat, fix, refactor, test, docs, chore
  - scope: 앱 약어 (auth, chat, admin 등)
- PR 생성 시 반드시 관련 Issue 번호 연결 (`Closes #123`)
- PR은 최소 1명 리뷰 후 머지

## 백엔드 공통 (Python/FastAPI)
- 패키지 관리: uv (pyproject.toml)
- 테스트: `uv run pytest --tb=short -q`
- 린트: `uv run ruff check .`
- 포맷: `uv run ruff format .`
- 타입체크: `uv run mypy .`
- IMPORTANT: 상세 백엔드 개발표준은 `@infra/docs/standards/backend-standards.md` 참조

### API 응답 형식
- 성공: `{"success": true, "data": any}`
- 실패: `{"success": false, "error": {"code": int, "name": str, "message": str}}`
- IMPORTANT: 모든 API는 위 형식을 따라야 함. 직접 dict 반환하지 말고 ServiceException 사용

### 에러 코드 체계
- 1XXXX: 클라이언트 오류 (4XX) — X0: 공통, X1: 인증, X2: 사용자, X3: 리소스, X4: 파일, X5: AI/모델
- 9XXXX: 서버 오류 (5XX) — 90: 일반, 94: 파일, 95: AI/모델, 98: 외부서비스, 99: DB
- 새 에러 코드 추가 시 위 번호 체계를 따르고, 다른 앱과 코드 번호가 충돌하지 않도록 주의

### 예외 처리 패턴
- 비즈니스 예외: `raise ServiceException(ErrorCode.XXX)` 또는 `raise ServiceException(ErrorCode.XXX, detail="상세 메시지")`
- bare except 금지 — 반드시 `except SpecificException as e:` 사용
- DB 에러: `except SQLAlchemyError` → `ServiceException(ErrorCode.DATABASE_ERROR)`
- 알 수 없는 에러: `error_handler.py`의 `unhandled_exception_handler`가 자동 처리

### 보안/인증 패턴
- Gateway 경유 요청: HTTP 헤더에서 사용자 정보 추출 (`username`, `company`, `user_id`, `email`, `role`)
- `get_current_user()` 의존성으로 사용자 정보 주입 — 라우터에서 직접 헤더 파싱 금지
- auth 서비스만 JWT 토큰 발급/검증 담당. 다른 서비스는 Gateway가 전달한 헤더 사용
- IMPORTANT: MASTER_KEY 비교 시 timing-safe comparison 사용

### 아키텍처 레이어
- `app/api/routes/` → 라우터 (요청/응답 처리만, 비즈니스 로직 금지)
- `app/service/` → 비즈니스 로직 (핵심 로직 여기에 구현)
- `app/service/model/` → Pydantic v2 모델 (요청/응답 스키마)
- `app/core/` → 설정, 에러처리, 로깅, 보안 (프레임워크 레벨)
- `app/infra/database/` → DB 스키마, 리포지토리 (SQLAlchemy)
- IMPORTANT: 라우터에 비즈니스 로직 직접 작성 금지. 반드시 service 레이어로 분리

### 로깅 규칙
- `get_logging()` → `logger` 사용. `print()` 금지
- YAML 기반 로깅 설정 (`logging_config.yaml`)
- 파일 로그 경로: `{DATA_PATH}/logs/{APP_NAME}/{APP_NAME}.log`
- 민감 정보(비밀번호, 토큰) 로그에 노출 금지

### DB 패턴
- SQLAlchemy ORM 사용, raw SQL 지양
- `get_db()` 제너레이터로 세션 관리 (FastAPI Depends)
- `pool_pre_ping=True` 필수 (연결 끊김 방지)
- `Base.metadata.create_all()` — 테이블 자동 생성 (개발용)
- 각 서비스는 독립 DB config 유지 (DB엔진이 다를 수 있음: mysql, postgresql)

## 프론트엔드 공통 (React/TypeScript)
- 패키지 관리: pnpm
- 빌드: `pnpm build`
- 개발서버: `pnpm dev`
- 린트: `pnpm lint`
- 타입체크: `pnpm type-check`
- IMPORTANT: 상세 프론트엔드 개발표준은 `@infra/docs/standards/frontend-standards.md` 참조

### 컴포넌트 패턴
- 함수형 컴포넌트 + hooks 패턴 (클래스 컴포넌트 사용 금지)
- 컴포넌트 파일당 하나의 `export default`
- 파일명: PascalCase (컴포넌트), camelCase (유틸리티, hooks)
- `useEffect` cleanup 빠뜨리지 않기

### 스타일링
- Tailwind CSS 사용, 인라인 스타일 사용 금지
- 글로벌 CSS는 `index.css`에서만 관리

### 상태관리
- jotai 아톰 (`src/store/`)
- 서버 상태와 클라이언트 상태 분리

### API 호출 패턴
- `@shared/lib/axios` 또는 `src/shared/lib/axios`의 `axiosInstance` 사용 (baseURL: `/api/v1`)
- 스트리밍 응답은 `fetch` + `text/event-stream` 사용
- API 호출은 반드시 `src/api/` 레이어를 통해 수행 — 컴포넌트에서 직접 호출 금지
- 서버 에러 응답 형식: `{"success": false, "error": {"code": int, "name": str, "message": str}}`
- camelCase ↔ snake_case 변환: `@shared/utils/caseConverter` 사용

### 공통 컴포넌트
- 공통 UI: `src/shared/` 디렉토리에서 import
- 앱 전용 컴포넌트: `src/components/`

### 다국어
- `src/locale/` 디렉토리에서 관리
- 하드코딩 문자열 금지

## 코드 포맷 & 린트 (전체 공통)
- IMPORTANT: 모든 레포에 `.editorconfig` 적용 — IDE 설정에 의존하지 않고 포맷 통일
- 백엔드: `ruff.toml` 공통 설정 사용 (shared-infra/configs/ruff.toml)
  - 린트: `uv run ruff check .` → 커밋 전 반드시 통과
  - 포맷: `uv run ruff format .` → 저장 시 자동 포맷 권장
  - import 정렬: ruff isort 규칙 자동 적용 (별도 isort 불필요)
  - print() 감지: T20 규칙으로 print 사용 시 경고
  - 보안 감지: S 규칙(bandit)으로 하드코딩 시크릿 등 감지
- 프론트엔드: `.prettierrc` 공통 설정 사용 (shared-infra/configs/.prettierrc)
  - 포맷: `pnpm prettier --write .` → 저장 시 자동 포맷 권장
  - 린트: `pnpm lint` (ESLint)
- Python 네이밍: snake_case (변수/함수), PascalCase (클래스), UPPER_CASE (상수)
- TypeScript 네이밍: camelCase (변수/함수), PascalCase (컴포넌트/인터페이스)
- 들여쓰기: Python 4칸, TypeScript/YAML/JSON 2칸 (editorconfig으로 자동 적용)

## PR 자동 리뷰
- 모든 레포에 `claude-review.yml` 설정됨
- PR 생성/업데이트 시 Claude가 자동으로 코드 리뷰 수행
- 리뷰 기준: 기능 충족, 아키텍처, 에러 처리, 보안, 코드 품질, 테스트
- PL은 Claude 리뷰 결과를 확인한 후 최종 Approve/머지 판단

## 공통 주의사항
- IMPORTANT: `.env`, 시크릿, API 키는 절대 커밋하지 않음
- IMPORTANT: 기존 코드 패턴을 먼저 확인하고 따를 것 — 새 패턴 도입 전 팀 합의
- IMPORTANT: 새 의존성 추가 전 기존 라이브러리로 해결 가능한지 확인
- 한국어 주석/문서 작성
- 각 서비스의 config.py, logging.py, error/*, security.py, database.py는 서비스별 독립 관리 (공통 패키지로 추출하지 않음)
- 에러 코드 번호 체계와 API 응답 형식만 전체 서비스 공통 규약으로 유지
