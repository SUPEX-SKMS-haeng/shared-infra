# 백엔드 개발표준 (Python/FastAPI)

이 문서는 agent-template-apps 백엔드 서비스의 개발표준을 정의합니다.
실제 코드에서 추출한 패턴이며, 모든 백엔드 서비스(auth, base, chat, llm-gateway, mcp)에 적용됩니다.

---

## 1. 프로젝트 구조

```
app/
├── main.py                    ← FastAPI 앱 생성, lifespan, 미들웨어 등록
├── api/
│   ├── router.py              ← 라우터 통합 (api_router)
│   ├── deps.py                ← FastAPI 의존성 (get_db, get_current_user 등)
│   └── routes/                ← 도메인별 라우터
│       └── {도메인}.py
├── service/
│   ├── {도메인}_service.py    ← 비즈니스 로직
│   └── model/                 ← Pydantic v2 요청/응답 모델
│       └── {도메인}.py
├── core/
│   ├── config.py              ← Settings (pydantic_settings)
│   ├── security.py            ← 인증/인가 헬퍼
│   ├── error/
│   │   ├── error_handler.py   ← FastAPI 예외 핸들러 등록
│   │   └── service_exception.py ← ErrorCode enum + ServiceException
│   └── log/
│       ├── logging.py         ← get_logging() 팩토리
│       └── logging_config.yaml
├── infra/
│   └── database/
│       ├── base.py            ← SQLAlchemy Base
│       ├── database.py        ← 엔진/세션 생성
│       ├── schema/            ← ORM 모델 (테이블 매핑)
│       └── repository/        ← 데이터 접근 계층
└── common/
    └── util/                  ← 유틸리티 함수
```

### 레이어 규칙

- **routes** → 요청 파싱, 응답 반환만 담당. 비즈니스 로직 금지.
- **service** → 핵심 비즈니스 로직. DB 접근은 repository를 통해 수행.
- **repository** → SQL 쿼리, ORM 조작만 담당. 비즈니스 판단 금지.
- **위반 예시**: 라우터에서 직접 `session.query()` 호출 → 반드시 service → repository 경유

---

## 2. 에러 처리

### 2.1 ErrorCode 정의 규칙

```python
# core/error/service_exception.py

@dataclass(frozen=True)
class ErrorInfo:
    http_status: int
    code: int        # 5자리 에러 코드
    message: str     # 기본 메시지 (한국어)

class ErrorCode(Enum):
    # 번호 체계: {HTTP유형}{도메인}{순번}
    # 1XXXX = 클라이언트(4XX), 9XXXX = 서버(5XX)
    # X0 = 공통, X1 = 인증, X2 = 사용자, X3 = 리소스
    # X4 = 파일, X5 = AI/모델, X8 = 외부서비스, X9 = 시스템/DB

    BAD_REQUEST = ErrorInfo(400, 10000, "잘못된 요청입니다")
    UNAUTHORIZED = ErrorInfo(401, 11000, "인증이 필요합니다")
    # ...
```

### 2.2 새 에러 코드 추가 시 규칙

1. 기존 에러 코드로 표현 가능한지 먼저 확인
2. 번호 체계에 맞는 코드 할당 (위 주석 참고)
3. 다른 서비스의 에러 코드 번호와 충돌 방지 — 서비스별 독립 관리이므로 같은 번호 가능하나 의미가 다르면 혼란
4. 메시지는 한국어로 작성, 사용자에게 보여줄 수 있는 수준으로

### 2.3 예외 발생 패턴

```python
# 기본 사용 — ErrorCode의 기본 메시지 사용
raise ServiceException(ErrorCode.USER_NOT_FOUND)

# 커스텀 메시지 — 디버깅 정보 추가
raise ServiceException(ErrorCode.USER_NOT_FOUND, detail="사용자 ID: abc123을 찾을 수 없습니다")

# 추가 데이터 포함
raise ServiceException(ErrorCode.VALIDATION_ERROR, detail="이메일 형식 오류", data={"field": "email"})
```

### 2.4 금지 패턴

```python
# ❌ bare except
try:
    ...
except:
    pass

# ❌ 에러 삼키기
try:
    ...
except Exception:
    return None  # 에러가 사라짐

# ❌ 라우터에서 직접 JSONResponse 에러 반환
return JSONResponse(status_code=400, content={"error": "bad"})

# ✅ 올바른 패턴
raise ServiceException(ErrorCode.BAD_REQUEST, detail="구체적 사유")
```

### 2.5 error_handler.py 구조 (수정하지 않음)

`set_error_handlers(app)`은 4가지 핸들러를 등록합니다:
1. `ServiceException` → 비즈니스 예외 (ErrorCode 기반 응답)
2. `RequestValidationError` → Pydantic 검증 실패 (400, 첫 번째 에러 필드 포함)
3. `StarletteHTTPException` → 일반 HTTP 예외 (상태코드별 ErrorCode 매핑)
4. `Exception` → 미처리 예외 (500, 프로덕션에서는 상세 메시지 숨김)

---

## 3. API 응답 형식

### 3.1 성공 응답

```json
{
  "success": true,
  "data": { ... }
}
```

### 3.2 실패 응답 (ServiceException이 자동 생성)

```json
{
  "success": false,
  "error": {
    "code": 12002,
    "name": "USER_NOT_FOUND",
    "message": "사용자를 찾을 수 없습니다"
  }
}
```

### 3.3 검증 실패 응답

```json
{
  "success": false,
  "error": {
    "code": 10001,
    "name": "VALIDATION_ERROR",
    "message": "입력값 검증 실패: body.email",
    "data": { "details": [...] }
  }
}
```

---

## 4. 보안/인증

### 4.1 인증 흐름

```
클라이언트 → Traefik Gateway → backend-auth (JWT 검증) → 헤더 주입 → 각 백엔드
```

- auth 서비스: JWT 토큰 발급/검증, bcrypt 비밀번호 해싱
- 다른 서비스: Gateway가 주입한 HTTP 헤더에서 사용자 정보 읽음

### 4.2 사용자 정보 추출 (auth 외 서비스)

```python
# core/security.py — 모든 서비스 공통 패턴
username_header = APIKeyHeader(name="username", scheme_name="username", auto_error=False)
company_header = APIKeyHeader(name="company", scheme_name="company", auto_error=False)
user_id_header = APIKeyHeader(name="user_id", scheme_name="user_id", auto_error=False)
email_header = APIKeyHeader(name="email", scheme_name="email", auto_error=False)
role_header = APIKeyHeader(name="role", scheme_name="role", auto_error=False)

def get_current_user(
    username=Depends(username_header),
    company=Depends(company_header),
    ...
) -> UserOrganizationRole:
    # 헤더값 디코딩 후 UserOrganizationRole 반환
```

### 4.3 라우터에서 사용자 정보 사용

```python
@router.get("/something")
async def get_something(
    current_user: UserOrganizationRole = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # current_user.user_id, current_user.company 등 사용
```

### 4.4 보안 금지 사항

- 라우터에서 직접 `request.headers["username"]` 접근 금지
- 비밀번호를 로그에 출력 금지
- MASTER_KEY를 평문 비교 금지 (timing-safe comparison 사용)
- `.env` 파일에 시크릿 저장 후 커밋 금지

---

## 5. 설정 관리 (config.py)

### 5.1 구조

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # 공통 섹션 (모든 서비스 동일)
    APP_NAME: str = "서비스명"
    APP_PORT: str = "8001"
    ENVIRONMENT: str = "local"
    DATA_PATH: str = "/data"
    LOG_LEVEL: str = "INFO"
    LOGGING_ENABLED: bool = True

    # 인프라 섹션 (대부분 동일, K8s ConfigMap으로 주입)
    DB_ENGINE: str = "mysql"
    DB_HOST: str = "127.0.0.1"
    REDIS_HOST: str = "127.0.0.1"

    # 서비스 고유 섹션 (서비스별 다름)
    # ...

@lru_cache()
def get_setting():
    return Settings()
```

### 5.2 규칙

- 모든 설정은 환경변수로 오버라이드 가능 (pydantic_settings 기본 동작)
- 기본값은 로컬 개발 환경용
- K8s에서는 ConfigMap(`common-config`, `infra-config`)과 Secret(`common-secret`)으로 주입
- 새 설정 추가 시 반드시 기본값 제공
- 서비스 고유 설정은 해당 서비스의 config.py에만 추가

---

## 6. DB 패턴

### 6.1 세션 관리

```python
# infra/database/database.py
def get_db():
    """FastAPI 의존성으로 사용"""
    SessionLocal = get_engine()
    session = SessionLocal()
    try:
        yield session
    except SQLAlchemyError as e:
        session.rollback()
        raise ServiceException(ErrorCode.DATABASE_ERROR)
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
```

### 6.2 ORM 스키마 (테이블 정의)

```python
# infra/database/schema/user.py
class UserTable(Base):
    __tablename__ = "user"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(50), unique=True, nullable=False)
    # ...
```

### 6.3 금지 패턴

- `session.execute(text("SELECT ..."))` — raw SQL 지양, ORM 쿼리 사용 (mcp의 동적 쿼리 제외)
- 트랜잭션 밖에서 `session.commit()` 호출 금지
- `get_db()` 밖에서 세션 생성 금지 (세션 누수 방지)

---

## 7. 로깅

### 7.1 기본 사용

```python
from core.log.logging import get_logging

logger = get_logging()

logger.info("작업 시작")
logger.error(f"에러 발생: {str(e)}")
logger.warning("주의 사항")
```

### 7.2 규칙

- `print()` 사용 금지 — 반드시 `logger` 사용
- 민감 정보(비밀번호, 토큰, API 키) 로그 출력 금지
- f-string에 전체 객체 dump 금지 (`logger.info(f"user={user}")` → 필요한 필드만)
- 에러 로그에는 traceback 포함: `logger.exception("에러 메시지")`

---

## 8. main.py 표준 구조

```python
from contextlib import asynccontextmanager
import uvicorn
from api.router import api_router
from core.config import get_setting
from core.error.error_handler import set_error_handlers
from core.log.logging import get_logging
from fastapi import FastAPI
from fastapi.routing import APIRoute

settings = get_setting()
logger = get_logging()

def create_app():
    def custom_generate_unique_id(route: APIRoute) -> str:
        return f"{route.tags[0]}-{route.name}"

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        logger.info(f"{settings.APP_NAME}[{settings.APP_PORT}] service is initializing...")
        # DB 초기화, Redis 연결 등
        logger.info(f"{settings.APP_NAME}[{settings.APP_PORT}] service is ready and now running!!")
        yield

    app = FastAPI(
        title=settings.APP_NAME,
        openapi_url=f"{settings.API_V1_STR}/openapi.json",
        lifespan=lifespan,
        generate_unique_id_function=custom_generate_unique_id,
    )
    app.include_router(api_router, prefix=settings.API_V1_STR)
    set_error_handlers(app)
    return app

app = create_app()
```

---

## 9. 사용자 모델 (UserOrganizationRole)

base, chat, llm-gateway가 공유하는 사용자 정보 모델입니다. 각 서비스에 복사본으로 존재합니다.

```python
# service/model/user.py
class UserRoles:
    common: str = "common"
    admin: str = "admin"
    superadmin: str = "superadmin"

class UserOrganizationInfo(BaseModel):
    org_id: int
    org_name: str
    org_description: str | None = None
    role: str | None = None

class UserOrganizationRole(BaseModel):
    default: str = "common"
    organizations: list[UserOrganizationInfo] = []
```

이 모델의 필드를 변경할 경우, 해당 모델을 사용하는 모든 서비스에서 동일하게 변경해야 합니다.

---

## 10. 체크리스트 — 새 기능 개발 시

1. [ ] GitHub Issue 확인 (요구사항, 수락 기준)
2. [ ] 기능 브랜치 생성 (`feat/{앱약어}/{이슈번호}-{설명}`)
3. [ ] 기존 코드 패턴 확인 후 동일 패턴 적용
4. [ ] service 레이어에 비즈니스 로직 구현
5. [ ] 에러 처리: ServiceException + 적절한 ErrorCode
6. [ ] Pydantic v2 모델로 요청/응답 스키마 정의
7. [ ] 테스트 작성 (`uv run pytest`)
8. [ ] 린트/포맷 확인 (`uv run ruff check . && uv run ruff format .`)
9. [ ] PR 생성 → Issue 번호 연결 → 리뷰 요청
