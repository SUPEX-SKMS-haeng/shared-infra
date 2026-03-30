# 코딩 표준 / 디렉토리 구조

## 멀티앱 구조

```
frontend/
├── admin/                    # 관리자 앱 (port 3001)
│   └── src/
│       ├── api/              # API 함수 (도메인별 파일)
│       ├── components/
│       │   ├── auth/         # 인증 관련 (ProtectedRoute 등)
│       │   ├── features/     # 도메인별 핵심 컴포넌트
│       │   │   ├── dashboard/
│       │   │   ├── deployments/
│       │   │   ├── organizations/
│       │   │   └── users/
│       │   ├── layout/       # AdminLayout
│       │   ├── sidebar/      # 사이드바 네비게이션
│       │   └── ui/           # 재사용 UI 컴포넌트
│       ├── data/             # Mock 데이터
│       ├── hooks/            # 커스텀 훅 (Data + Handler)
│       ├── locale/           # i18n (config.ts, ko/)
│       ├── pages/            # 독립 전체화면 (Login 등)
│       ├── routes/           # AppRoutes.tsx
│       ├── store/            # Jotai atom (UI 상태)
│       └── types/            # TypeScript 타입 정의
├── chat/                     # 채팅 앱 (port 3000)
│   └── src/
│       ├── api/              # API 함수
│       ├── components/
│       │   ├── auth/         # 인증 관련
│       │   ├── chat/         # 채팅 컴포넌트
│       │   ├── common/       # 공통 UI
│       │   ├── layout/       # ChatLayout
│       │   ├── sidebar/      # 사이드바 (채팅 히스토리)
│       │   ├── topbar/       # 상단바 (그룹·모델 선택)
│       │   └── ui/           # 재사용 UI 컴포넌트
│       ├── hooks/            # 커스텀 훅
│       ├── lib/              # 앱 전용 유틸
│       ├── locale/           # i18n
│       ├── pages/            # 독립 전체화면
│       ├── routes/           # AppRoutes.tsx
│       ├── store/            # Jotai atom
│       └── types/            # TypeScript 타입 정의
└── shared/                   # 양쪽 앱 공통 코드
    ├── api/                  # 공통 API (auth, group)
    ├── components/           # 공통 컴포넌트 (LoginForm 등)
    │   └── auth/
    ├── hooks/                # 공통 훅 (useAuth, useAxiosInterceptor 등)
    ├── lib/                  # axios 인스턴스, queryClient
    ├── store/                # 공통 atom (인증 상태)
    ├── types/                # 공통 타입 (auth)
    └── utils/                # 유틸 (cn, caseConverter)
```

### 앱별 디렉토리 특징

- 각 앱의 `src/` 내부는 **도메인 하위 폴더 없이 플랫 구조** (앱 자체가 도메인)
  - `admin/src/api/user.ts` (O) — `admin/src/api/admin/user.ts` (X)
  - `admin/src/hooks/useUserData.ts` (O) — `admin/src/hooks/admin/useUserData.ts` (X)
- `shared/`는 `src/` 없이 루트에 바로 모듈 배치
- 공통 코드는 반드시 `shared/`에 배치, 앱 간 코드 복사 금지

### Import alias 규칙

- `@/` → 해당 앱의 `./src/` (앱 내부 코드)
- `@shared/` → `../shared/` (공통 코드)
- 상대 경로 import 금지
- Import 순서: ① 표준 라이브러리 → ② 서드파티 패키지 → ③ `@shared/` → ④ `@/`

---

## 코딩 표준

- **문법**: 화살표 함수만 사용
- **TypeScript**: strict 모드 준수. `any` 사용 금지. Props와 데이터 모델은 `interface` 선호
- **네이밍**: 컴포넌트·파일명은 `PascalCase`, 훅·유틸·변수명은 `camelCase`

### 타입 정의 규칙

- 위치: `{app}/src/types/{domain}.ts` — 공통 타입은 `shared/types/`
- 타입/인터페이스 이름은 `PascalCase`, 필드명은 `camelCase` (snake_case 원본 타입 정의 금지)
- **도메인 모델 우선 정의** (`User`, `Chat` 등) → Response/Request 타입에서 참조
- **Response**: 응답이 도메인 모델 그 자체면 별도 Response 타입 미정의. 추가 필드가 있을 때만 정의
- **Request body**: `{Action}{Domain}Body` (예: `CreateUserBody`)
- **Request params**: `{Action}{Domain}Params` (예: `GetUserListParams`)
- named export만

### API 호출 패턴

- `@shared/lib/axios`의 `axiosInstance` 사용 필수 — 직접 `axios` import 금지
- 위치: `{app}/src/api/{domain}.ts`
- 함수명: 동사+명사 (`getUsers`, `getUserById`, `createUser`)
- `URL_PREFIX`는 도메인명 기반 (예: `'/users'`, `'/deployments'`)
- **`body` vs `params` 명시적 구분**:
  - GET: `params` 파라미터 → `{ params }` 옵션
  - POST/PATCH/PUT: `body` 파라미터 → 두 번째 인자
- API 함수 내 변환/직렬화 로직 금지 — `@shared/hooks/useAxiosInterceptor`에서 일괄 처리
- named export만

### 컴포넌트 규칙

- 함수형 컴포넌트만 사용 — 클래스 컴포넌트 금지
- Props는 해당 컴포넌트 파일 상단에 `interface`로 선언, 이름은 `{컴포넌트명}Props`
- 파일당 하나의 `export default` 컴포넌트
- `useEffect`에 cleanup 함수 빠뜨리지 않기

### 스타일링 규칙

- **Tailwind CSS** 전용 — 인라인 `style` 금지
- 글로벌 CSS는 `{app}/src/index.css`에서만 정의
- 컴포넌트별 CSS 파일 생성 금지
- 색상은 CSS 변수 기반 시맨틱 클래스 (`bg-background`, `text-foreground` 등) — 하드코딩 금지
- 반응형: Tailwind 브레이크포인트 (`sm:`, `md:`, `lg:`)

### 다국어 (i18n) 규칙

- 설정: `{app}/src/locale/config.ts`
- 번역 파일: `{app}/src/locale/ko/common.json`
- UI 텍스트 하드코딩 금지 — `t()` 함수로 참조

### 컴포넌트 책임 분리

| 레이어 | 역할 |
|--------|------|
| `shared/api/`, `{app}/src/api/` | 순수 API 함수만. `axiosInstance`로 HTTP 요청 |
| `shared/store/`, `{app}/src/store/` | 순수 클라이언트 상태만. `atomWithQuery`/`atomWithMutation` 정의하지 않음 |
| `shared/hooks/`, `{app}/src/hooks/` | 비즈니스 로직. `atomWithQuery`/`atomWithMutation` 정의, 데이터 가공, 이벤트 처리 |
| `{app}/src/components/` | UI 렌더링만. 훅의 atom을 소비, 이벤트 핸들러 연결 |

### hooks/ 파일 분류

| 파일 패턴 | 역할 | 예시 |
|-----------|------|------|
| `use{Domain}Data.ts` | API 데이터 조회/변경 atom 정의 | `useUserData.ts`, `useLlmGatewayData.ts` |
| `use{Domain}Handler.ts` 또는 `use{기능명}Handler.ts` | 기능 로직 (이벤트 처리, 검증, 데이터 가공) | `useUserTableHandler.ts`, `useChatSendHandler.ts` |

**컴포넌트 내부 vs 핸들러 훅 분리 기준:**

| 컴포넌트 내부 OK | 핸들러 훅으로 분리 |
|---|---|
| 단순 UI 상태 (`useState`로 open/close, 입력값 등) | 여러 컴포넌트에서 공유하는 로직 |
| 단순 포맷팅/문자열 조합 | 여러 API를 조합하거나 순차 호출하는 로직 |
| API 호출이 단순 1회 호출 + toast 수준 | 유효성 검증 + 데이터 가공 + API 호출이 결합된 복합 로직 |

> 원칙: **단일 컴포넌트 전용 + 로직이 단순하면 내부, 공유되거나 복합적이면 훅으로 분리**

---

## 데이터 변환 규칙

- 백엔드 API 응답: `snake_case` → 프론트엔드 모델: `camelCase`
- 변환 주체: `@shared/hooks/useAxiosInterceptor`에서 전역 처리
  - 응답: snake_case → camelCase 자동 변환
  - 요청 페이로드: camelCase → snake_case 자동 재변환
  - 요청 params: `qs` 직렬화 일괄 처리
- API 함수에서 별도 변환/직렬화 로직 추가 금지

---

## 워크플로우 제약

- 기존 폴더 구조와 네이밍 규칙 절대 변경 금지
- 양쪽 앱에서 사용하는 코드는 `shared/`로 추출
- `shared/` 수정 시 admin, chat 양쪽에서 호환성 확인 필수
- API 연동 시 Foundation → UI 순서 준수 (types → api → store → hooks → 컴포넌트 연결)
