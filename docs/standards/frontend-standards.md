# 프론트엔드 개발표준 (React/TypeScript)

이 문서는 agent-template-apps 프론트엔드 서비스의 개발표준을 정의합니다.
실제 코드에서 추출한 패턴이며, frontend 레포에 적용됩니다.

---

## 1. 프로젝트 구조

### frontend (통합 레포)

```
frontend/                          ← 1개 레포
├── admin/                         ← 관리자 대시보드 (:3001)
│   ├── package.json
│   ├── vite.config.ts             ← @/ → ./src, @shared → ../shared
│   └── src/
│       ├── api/                   ← API 호출 함수 (도메인별 파일)
│       ├── components/
│       │   ├── features/          ← 도메인별 컴포넌트 (users, organizations 등)
│       │   ├── layout/            ← AdminLayout
│       │   ├── sidebar/           ← 네비게이션
│       │   └── ui/                ← 재사용 UI (DataTable, Modal 등)
│       ├── hooks/                 ← use*Data.ts, use*TableHandler.ts
│       ├── store/                 ← jotai 스토어 (*UI.ts)
│       ├── types/                 ← TypeScript 타입
│       ├── pages/                 ← 페이지 컴포넌트
│       ├── routes/                ← 라우터 설정
│       └── locale/                ← 다국어 설정
├── chat/                          ← 채팅 UI (:3000)
│   ├── package.json
│   ├── vite.config.ts             ← @/ → ./src, @shared → ../shared
│   └── src/
│       ├── api/                   ← chat, llmGateway API
│       ├── components/
│       │   ├── chat/              ← ChatBubble, MessageInput 등
│       │   ├── layout/            ← ChatLayout
│       │   ├── sidebar/           ← 채팅 히스토리
│       │   └── ui/                ← 공통 UI
│       ├── hooks/                 ← 채팅 관련 hooks
│       ├── store/                 ← chat, scroll 스토어
│       ├── types/                 ← chat, message 타입
│       ├── pages/                 ← 페이지 컴포넌트
│       ├── routes/                ← 라우터 설정
│       └── locale/                ← 다국어 설정
└── shared/                        ← 공통 라이브러리 (@shared alias)
    ├── api/                       ← 공통 API (auth, group)
    ├── components/                ← 공통 컴포넌트 (LoginForm 등)
    ├── hooks/
    │   ├── useAuth.ts             ← 인증 훅 (로그인/로그아웃)
    │   ├── useAxiosInterceptor.ts ← axios 인터셉터 (자동 케이스 변환, 401 처리)
    │   └── useFetchInterceptor.ts ← fetch 인터셉터
    ├── lib/
    │   ├── axios.ts               ← axiosInstance (baseURL: /api/v1)
    │   └── queryClient.ts         ← TanStack Query 인스턴스
    ├── store/
    │   └── auth.ts                ← jotai 인증 상태 (userAtom, selectedGroupAtom)
    ├── types/
    │   └── auth.ts                ← 인증 관련 타입
    └── utils/
        ├── caseConverter.ts       ← camelCase ↔ snake_case 변환
        └── utils.ts               ← 유틸리티 함수
```

---

## 2. API 호출 패턴

### 2.1 axiosInstance 사용

```typescript
// src/api/user.ts
import { axiosInstance } from '@shared/lib/axios';

export const getUserList = async (params: { offset: number; limit: number }) => {
  const { data } = await axiosInstance.get<IUserListResponse>('/auth/user', { params });
  return data;
};
```

### 2.2 규칙

- `axiosInstance`는 `@shared/lib/axios`에서 import (직접 `axios.create` 금지)
- API 호출 함수는 `src/api/` 디렉토리에만 정의 — 컴포넌트에서 직접 호출 금지
- URL prefix: `/auth/user`, `/chat/simple` 등 (baseURL `/api/v1`이 자동 추가됨)
- 스트리밍 응답 (SSE): `fetch` + `text/event-stream` 사용 (axios는 스트리밍 미지원)

### 2.3 케이스 자동 변환

`useAxiosInterceptor`가 자동 처리:
- **요청**: `camelCase` → `snake_case` (params, data)
- **응답**: `snake_case` → `camelCase` (response.data)
- FormData는 변환 제외
- IMPORTANT: 프론트엔드 코드에서는 항상 camelCase 사용. 백엔드 snake_case를 직접 쓰지 않음

### 2.4 서버 에러 응답 처리

백엔드는 아래 형식으로 에러를 반환합니다:

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

프론트엔드에서 에러 처리 시:
```typescript
try {
  const result = await someApi();
} catch (error) {
  if (axios.isAxiosError(error) && error.response?.data?.error) {
    const { code, message } = error.response.data.error;
    // code별 분기 또는 message를 사용자에게 표시
  }
}
```

---

## 3. 인증 패턴

### 3.1 로그인 흐름

```
LoginForm → useAuth().login() → POST /auth/login → accessToken 저장 → userAtom 설정
```

### 3.2 토큰 관리

- `localStorage.setItem('accessToken', token)` — 로그인 시 저장
- `useAxiosInterceptor`가 모든 요청에 `Authorization: Bearer {token}` 자동 추가
- 401 응답 시: localStorage 클리어 → `/login`으로 리다이렉트

### 3.3 사용자 상태

```typescript
// shared/store/auth.ts (jotai)
const userAtom = atom<User | null>(null);
const selectedGroupAtom = atom<GroupInfo | null>(null);
const userGroupsAtom = atom<GroupInfo[]>([]);
```

- `useAuth()` — 로그인/로그아웃 동작
- `useCurrentUser()` — 현재 사용자 정보, isSuperAdmin 판단

---

## 4. 컴포넌트 규칙

### 4.1 파일 구조

```typescript
// PascalCase 파일명: UserProfile.tsx
import { useState } from 'react';

interface UserProfileProps {
  userId: string;
  // ...
}

const UserProfile = ({ userId }: UserProfileProps) => {
  // ...
  return <div>...</div>;
};

export default UserProfile;
```

### 4.2 규칙

- 함수형 컴포넌트 + hooks (클래스 컴포넌트 금지)
- 파일당 하나의 `export default`
- Props 인터페이스는 컴포넌트 파일 상단에 정의
- `useEffect`에 cleanup 함수 빠뜨리지 않기
- 인덱스 파일(`index.ts`)로 barrel export 관리

### 4.3 디렉토리별 컴포넌트 분류

```
components/
├── ui/          ← 범용 UI (DataTable, Modal, Pagination, SearchBar 등)
├── sidebar/     ← 사이드바 관련
├── chat/        ← 채팅 도메인 (ChatBubble, MessageInput 등)
└── {도메인}/    ← 기타 도메인별 컴포넌트
```

- **공통 UI** (`@shared/components/`): 두 앱 이상에서 사용하는 컴포넌트
- **앱 전용** (`src/components/`): 해당 앱에서만 사용하는 컴포넌트
- IMPORTANT: 공통 후보인데 한쪽 앱에만 있는 경우, 필요 시 `shared/`로 이동

---

## 5. 상태관리

### 5.1 라이브러리

- **jotai**: 인증 상태 (`@shared/store/`), 앱별 UI 상태 (`src/store/`)
- **jotai-tanstack-query**: 서버 상태 (`atomWithQuery`/`atomWithMutation`)
- 새로 만들 때는 해당 앱의 기존 패턴을 따름

### 5.2 규칙

- 서버 상태 (API 데이터)는 `@tanstack/react-query` 사용 가능 (useAuth에서 이미 사용 중)
- 클라이언트 상태 (UI 상태)는 jotai atom
- 전역 상태 남용 금지 — 컴포넌트 로컬 `useState`로 충분하면 전역 스토어 사용하지 않음

---

## 6. 타입 정의

### 6.1 위치

- `src/types/` — 앱별 도메인 타입
- `@shared/types/` — 공통 타입 (인증 등)

### 6.2 네이밍 컨벤션

```typescript
// 인터페이스: I 접두사
interface IUserListResponse {
  success: boolean;
  data: IUser[];
}

// 요청 타입
interface LoginRequest {
  userId: string;
  password: string;
}
```

### 6.3 규칙

- `any` 사용 최소화 — 구체적 타입 정의
- API 응답/요청 타입은 반드시 정의 (`axiosInstance.get<IResponse>`)
- 백엔드 Pydantic 모델과 필드명은 동일하게 유지 (camelCase로 자동 변환된 상태 기준)

---

## 7. 스타일링

- **Tailwind CSS** 전용 — 인라인 `style` 금지
- 글로벌 CSS는 `src/index.css`에서만 정의
- 컴포넌트별 CSS 파일 생성 금지 — Tailwind 유틸리티 클래스 사용
- 반응형: Tailwind 브레이크포인트 (`sm:`, `md:`, `lg:`) 사용

---

## 8. 다국어 (i18n)

- `src/locale/config.ts`에서 설정
- UI 텍스트 하드코딩 금지 — locale 파일에 정의 후 참조
- 에러 메시지: 백엔드에서 한국어로 반환되므로 그대로 표시 가능

---

## 9. 에러 처리 패턴

### 9.1 axios 인터셉터 (글로벌)

`useAxiosInterceptor`에서 처리:
- **401**: localStorage 클리어 → 로그인 페이지 리다이렉트
- **기타 4XX/5XX**: `Promise.reject(error)` 반환 → 호출부에서 처리

### 9.2 컴포넌트 레벨

```typescript
// useMutation 에러 처리
const mutation = useMutation({
  mutationFn: createUser,
  onError: (error) => {
    // error.response.data.error.message 사용자에게 표시
  },
});
```

### 9.3 금지 패턴

```typescript
// ❌ 에러 무시
try { await api(); } catch {}

// ❌ console.log로만 처리
catch (e) { console.log(e); }

// ❌ 사용자에게 에러 미표시
// → 반드시 toast, alert, 또는 UI에 에러 상태 반영
```

---

## 10. 체크리스트 — 새 기능 개발 시

1. [ ] GitHub Issue 확인
2. [ ] 기능 브랜치 생성
3. [ ] 기존 코드 패턴 확인 후 동일 패턴 적용
4. [ ] 타입 정의 (`src/types/`)
5. [ ] API 함수 작성 (`src/api/`)
6. [ ] 컴포넌트 구현 (공통은 `@shared/`, 전용은 `src/components/`)
7. [ ] 에러 처리: 사용자에게 에러 메시지 표시
8. [ ] 라우터 등록 (새 페이지인 경우)
9. [ ] 린트/타입체크 (`pnpm lint && pnpm type-check`)
10. [ ] shared 수정 시 영향 범위 확인
