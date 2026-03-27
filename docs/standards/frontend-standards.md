# 프론트엔드 개발표준 (React/TypeScript)

> **적용 대상**: frontend (chat + admin 통합 단일 레포)
> **기술 스택**: React 19 / TypeScript 5.9 / Vite 8 / Tailwind CSS 4
> **UI 컴포넌트**: shadcn/ui (Radix 기반)
> **상태관리**: jotai + jotai-tanstack-query (atomWithQuery/atomWithMutation)
> **패키지 관리**: pnpm
> **린트/포맷**: ESLint (flat config) + Prettier (shared-infra/configs/.prettierrc)
> **최종 업데이트**: 2026-03-27

이 문서는 agent-template-apps 프론트엔드 서비스의 개발표준을 정의합니다.
실제 코드에서 추출한 패턴이며, frontend 레포에 적용됩니다.

---

## 0. 개발 환경

- 패키지 관리: `pnpm`
- 빌드: `pnpm build` (tsc -b && vite build)
- 개발서버: `pnpm dev` (port 3000, API proxy → localhost:8000)
- 린트: `pnpm lint` (ESLint flat config)
- 타입체크: `pnpm type-check`
- 빌드 도구: Vite 8, TypeScript 5.9 (strict mode)
- React 19

---

## 1. 프로젝트 구조

### 도메인 구조

chat, admin, auth 3개 도메인이 단일 레포에 통합되어 있습니다.

```
src/
├── api/{domain}/           ← 도메인별 API (admin/, auth/, chat/)
├── components/
│   ├── ui/                 ← shadcn/ui 기반 공통 컴포넌트
│   ├── layout/{domain}/    ← 도메인별 레이아웃 (admin/, chat/)
│   └── features/{domain}/  ← 도메인별 기능 컴포넌트 (admin/, auth/, chat/)
├── hooks/{domain}/         ← 도메인별 hooks (data hooks + handler hooks)
├── store/{domain}/         ← 도메인별 jotai 아톰
├── types/{domain}/         ← 도메인별 타입 + common/
├── locale/ko/{domain}.json ← 도메인별 번역 파일
├── routes/                 ← React Router (ProtectedRoute 포함)
├── pages/                  ← 전체 페이지 (Login, 404, 403)
├── lib/                    ← 라이브러리 래퍼 (axios, queryClient)
├── utils/                  ← 유틸리티 (caseConverter 등)
└── data/                   ← 목 데이터 (개발용)
```

### 라우팅

- `/` — chat 도메인
- `/admin` — admin 도메인
- `ProtectedRoute`로 인증/권한 제어

---

## 2. API 호출 패턴

### 2.1 axiosInstance 사용

```typescript
// src/api/admin/user.ts
import { axiosInstance } from '@/lib/axios';

export const getUserList = async (params: { offset: number; limit: number }) => {
  const { data } = await axiosInstance.get<IUserListResponse>('/auth/user', { params });
  return data;
};
```

### 2.2 규칙

- `axiosInstance`는 `@/lib/axios`에서 import (직접 `axios.create` 금지)
- API 호출 함수는 `src/api/{domain}/` 디렉토리에만 정의 — 컴포넌트에서 직접 호출 금지
- URL prefix: `/auth/user`, `/chat/simple` 등 (baseURL `/api/v1`이 자동 추가됨)
- 스트리밍 응답 (SSE): `fetch` + `text/event-stream` 사용 (axios는 스트리밍 미지원)

### 2.3 케이스 자동 변환

`useAxiosInterceptor`가 자동 처리:
- **요청**: `camelCase` → `snake_case` (params, data)
- **응답**: `snake_case` → `camelCase` (response.data)
- FormData는 변환 제외
- 변환 유틸: `@/utils/caseConverter`
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
// src/store/auth/
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
}

const UserProfile = ({ userId }: UserProfileProps) => {
  return <div>...</div>;
};

export default UserProfile;
```

### 4.2 규칙

- 함수형 컴포넌트 + hooks (클래스 컴포넌트 금지)
- arrow function only
- 파일당 하나의 `export default`
- Props 인터페이스는 컴포넌트 파일 상단에 정의
- `useEffect`에 cleanup 함수 빠뜨리지 않기

### 4.3 디렉토리별 컴포넌트 분류

```
components/
├── ui/                  ← shadcn/ui 기반 공통 컴포넌트
├── layout/{domain}/     ← 도메인별 레이아웃 (admin/, chat/)
└── features/{domain}/   ← 도메인별 기능 컴포넌트 (admin/, auth/, chat/)
```

- **공통 UI** (`components/ui/`): shadcn/ui 기반, 여러 도메인에서 재사용
- **도메인별 기능** (`components/features/{domain}/`): 특정 도메인에서만 사용하는 컴포넌트

---

## 5. 상태관리

### 5.1 라이브러리

- **jotai**: 클라이언트 상태 (UI 상태)
- **jotai-tanstack-query**: 서버 상태 (`atomWithQuery`, `atomWithMutation`)

### 5.2 규칙

- 서버 상태는 `atomWithQuery`/`atomWithMutation` 사용
- IMPORTANT: 직접 `useQuery`/`useMutation` 사용 금지 — jotai-tanstack-query를 통해 사용
- `store/{domain}/` — 순수 클라이언트 상태 (UI 상태)
- `hooks/{domain}/` — 서버 상태 (atomWithQuery) + 비즈니스 로직
- 전역 상태 남용 금지 — 컴포넌트 로컬 `useState`로 충분하면 전역 스토어 사용하지 않음

---

## 6. 타입 정의

### 6.1 위치

- `src/types/{domain}/` — 도메인별 타입
- `src/types/common/` — 공통 타입 (Pagination 등)

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

- **Tailwind CSS 4** 전용 (via `@tailwindcss/vite` 플러그인) — 인라인 `style` 금지
- **shadcn/ui** (Radix 기반) 공통 컴포넌트
- 글로벌 CSS는 `src/index.css`에서만 정의
- 컴포넌트별 CSS 파일 생성 금지 — Tailwind 유틸리티 클래스 사용
- 반응형: Tailwind 브레이크포인트 (`sm:`, `md:`, `lg:`) 사용

---

## 8. 다국어 (i18n)

- `src/locale/ko/{domain}.json` — 도메인별 번역 파일
- `src/locale/config.ts`에서 설정
- UI 텍스트 하드코딩 금지 — locale 파일에 정의 후 참조
- 에러 메시지: 백엔드에서 한국어로 반환되므로 그대로 표시 가능

---

## 9. 에러 처리 패턴

### 9.1 axios 인터셉터 (글로벌)

`useAxiosInterceptor`에서 처리:
- **401**: localStorage 클리어 → 로그인 페이지 리다이렉트
- **기타 4XX/5XX**: `Promise.reject(error)` 반환 → 호출부에서 처리

### 9.2 금지 패턴

```typescript
// ❌ 에러 무시
try { await api(); } catch {}

// ❌ console.log로만 처리
catch (e) { console.log(e); }

// ❌ 사용자에게 에러 미표시
// → 반드시 toast, alert, 또는 UI에 에러 상태 반영
```

---

## 10. 코드 포맷 & 린트

### 10.1 Prettier

- 공통 설정 파일: `shared-infra/configs/.prettierrc`
- 포맷: `pnpm prettier --write .` → 저장 시 자동 포맷 권장

### 10.2 ESLint

- flat config 사용
- 린트: `pnpm lint`

### 10.3 네이밍 규칙

- 변수/함수: `camelCase`
- 컴포넌트/인터페이스: `PascalCase`
- 파일명: PascalCase (컴포넌트), camelCase (유틸리티, hooks)
- 들여쓰기: 2칸

### 10.4 import 규칙

- 절대 경로 `@/` only — 상대 경로 금지
- 예: `import { axiosInstance } from '@/lib/axios'`

### 10.5 editorconfig

- 모든 레포에 `.editorconfig` 적용 — IDE 설정에 의존하지 않고 포맷 통일

---

## 11. 체크리스트 — 새 기능 개발 시

1. [ ] GitHub Issue 확인
2. [ ] 기능 브랜치 생성
3. [ ] 기존 코드 패턴 확인 후 동일 패턴 적용
4. [ ] 타입 정의 (`src/types/{domain}/`)
5. [ ] API 함수 작성 (`src/api/{domain}/`)
6. [ ] 컴포넌트 구현 (공통: `components/ui/`, 도메인별: `components/features/{domain}/`)
7. [ ] 에러 처리: 사용자에게 에러 메시지 표시
8. [ ] 라우터 등록 (새 페이지인 경우)
9. [ ] 린트/타입체크 (`pnpm lint && pnpm type-check`)
