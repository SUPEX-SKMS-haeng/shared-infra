---
paths:
  - "**/api/**"
  - "**/types/**"
  - "**/hooks/**"
---

# API 연동 절차

백엔드 FastAPI 소스를 분석하여 프론트엔드 타입/API/상태관리/훅/컴포넌트를 연결하는 절차.
Foundation → UI 순서를 반드시 지킨다.

> API 연동 작업 시 **대상 앱(admin | chat)**과 **도메인명**을 먼저 확인한다.

---

## Step 1 — 백엔드 소스 분석

### 파일 탐색 (FastAPI 기준)

CLAUDE.md의 "백엔드 연동 정보"에서 경로를 참조한다.
도메인명 기준 아래 순서로 탐색:

1. `{백엔드 루트}/app/api/routes/{domain}.py`
2. `{백엔드 루트}/app/service/model/{domain}.py`
3. `{백엔드 루트}/app/service/{domain}.py`

읽어야 할 파일:

- 라우터 파일 — 엔드포인트 정의 (method, path, 파라미터)
- 모델 파일 — Pydantic v2 모델 (타입 정의)
- 서비스 파일 — 비즈니스 로직 (필요 시 참조)

### 추출할 정보

| 항목           | 예시                                 |
| -------------- | ------------------------------------ |
| Method + Path  | `GET /api/v1/users`                  |
| Path Params    | `user_id: int`                       |
| Query Params   | `page: int, size: int`               |
| Request Body   | `CreateUserRequest`                  |
| Response Model | `UserResponse`, `List[UserResponse]` |
| 인증           | `Depends(get_current_user)` 여부     |

---

## Step 2 — types/ 정의

위치: `{app}/src/types/{domain}.ts` — 공통 타입은 `shared/types/`

규칙:

- 타입/인터페이스 이름은 PascalCase, 필드명은 camelCase
- `any` 금지, `interface` 선호
- Axios interceptor가 snake_case ↔ camelCase 자동 변환하므로 api 함수 내 변환 로직 추가 금지
- named export만

### Request/Response 타입 정의

**Response 타입:**

- 도메인 모델 우선 정의 → Response 타입에서 참조
- 응답이 도메인 모델 그 자체면 별도 Response 타입 없이 직접 사용
- 추가 필드가 있을 때만 Response 타입 정의

**Request 타입:**

- POST/PATCH/PUT body → `{Action}{Domain}Body`
- GET query params → `{Action}{Domain}Params`

```typescript
// 예시: admin/src/types/user.ts
export interface User {
  id: number;
  name: string;
  email: string;
  role: string;
  isActive: boolean;
  createdAt: string;
}

export interface GetUsersResponse {
  users: User[];
  totalCount: number;
}

export interface CreateUserBody {
  name: string;
  email: string;
  role: string;
}

export interface GetUserListParams {
  offset: number;
  limit: number;
  searchCategory?: string;
  searchKeyword?: string;
}
```

---

## Step 3 — api/ 정의

위치: `{app}/src/api/{domain}.ts`

규칙:

- `@shared/lib/axios`의 `axiosInstance` import (직접 `axios` import 금지)
- 함수명: 동사+명사
- `URL_PREFIX`는 도메인명 기반
- **`body` vs `params` 명시적 구분**
- API 함수 내 변환/직렬화 로직 금지
- named export만

```typescript
// 예시: admin/src/api/user.ts
import { axiosInstance } from '@shared/lib/axios';
import type {
  User,
  GetUsersResponse,
  GetUserListParams,
  CreateUserBody,
} from '@/types/user';

const URL_PREFIX = '/users';

export const getUserList = async (
  params: GetUserListParams
): Promise<GetUsersResponse> => {
  const { data } = await axiosInstance.get(URL_PREFIX, { params });
  return data;
};

export const createUser = async (body: CreateUserBody): Promise<User> => {
  const { data } = await axiosInstance.post(URL_PREFIX, body);
  return data;
};
```

---

## Step 4 — store/ 클라이언트 상태 정의

위치: `{app}/src/store/{domain}UI.ts`

- 규칙 및 예시는 @.claude/rules/state-management.md "클라이언트 상태 — Jotai" 참조
- 해당 도메인에 공유할 클라이언트 상태가 없으면 생략 가능

---

## Step 5 — hooks/ 작성

위치: `{app}/src/hooks/use{Domain}Data.ts`

- `atomWithQuery`/`atomWithMutation` 정의 규칙은 @.claude/rules/state-management.md 참조
- `queryClient`는 `@shared/lib/queryClient`에서 import
- 기존 Mock 훅의 반환 인터페이스를 최대한 유지하여 컴포넌트 변경 최소화
- isLoading, error 상태 포함

---

## Step 6 — 핸들러 훅 작성

위치: `{app}/src/hooks/use{Domain}Handler.ts` 또는 `use{기능명}Handler.ts`

- 분리 기준은 @.claude/rules/coding-standards.md "hooks/ 파일 분류" 참조
- API 호출이 필요한 핸들러는 Step 5의 API atom을 import하여 사용
- 해당 도메인에 핸들러 훅이 필요 없으면 생략 가능

---

## Step 7 — 컴포넌트 연결

Mock 데이터로 구현된 컴포넌트를 실제 백엔드 API로 교체하여 연동을 완성한다.

작업 내용:

- 하드코딩 더미 데이터 → Step 5 API atom import로 교체
- 빈 이벤트 핸들러 → Step 6 핸들러 훅의 함수 연결
- isLoading → 로딩 처리
- error → toast로 에러 메시지 표시
- 하드코딩 문자열 → `t()` 교체 + locale 파일에 키 추가

### atom 사용 패턴

컴포넌트에서 atom을 사용하는 패턴은 @.claude/rules/state-management.md "컴포넌트에서 atom 사용" 참조.

금지:

- 마크업/레이아웃 구조 변경
- 복합/공유 로직을 컴포넌트 안에 직접 작성 (단순 로직은 내부 OK)
- `any` 타입 사용

---

## 전체 완료 체크리스트

- [ ] types/ — 타입명 PascalCase, 필드명 camelCase, `any` 없음
- [ ] types/ — 응답이 도메인 모델 그 자체면 별도 Response 미정의
- [ ] api/ — `@shared/lib/axios` 사용, 함수명 동사+명사, URL_PREFIX 도메인명 기반
- [ ] api/ — 변환/직렬화 로직 없음 (interceptor에서 일괄 처리)
- [ ] store/ — 순수 클라이언트 상태만 정의
- [ ] hooks/Data — `atomWithQuery`/`atomWithMutation` 정의, `queryClient`는 `@shared/lib/queryClient`에서 import
- [ ] hooks/Handler — 컴포넌트 기능 로직이 핸들러 훅으로 분리됨
- [ ] 컴포넌트 — Mock 데이터 → 실제 API atom으로 교체 완료
- [ ] 컴포넌트 — Query는 `useAtomValue`, Mutation은 `useSetAtom` 사용
- [ ] `any` 타입 없음
- [ ] import 경로가 `@/` 또는 `@shared/` 절대 경로
- [ ] Mock 데이터 파일(`data/`)은 삭제하지 않음

---

## 주의사항

- 백엔드 경로를 찾을 수 없으면 사용자에게 경로를 질문
- 도메인 전체가 아닌 특정 API만 추가하는 경우, 기존 파일에 추가 (새 파일 생성 X)
- store에 공유할 클라이언트 상태가 없으면 Step 4 생략 가능
- 핸들러 훅이 불필요하면 Step 6 생략 가능
