---
paths:
  - "**/store/**"
  - "**/hooks/**"
---

# 상태 관리 패턴

> 경로 표기에서 `{app}`은 `admin` 또는 `chat`을 의미합니다.

## 클라이언트 상태 — Jotai

### 앱별 상태

위치: `{app}/src/store/{domain}UI.ts` 또는 `{domain}.ts`

- **순수 클라이언트 상태만 정의** (선택된 항목, 필터 조건, UI 상태 등)
- `atomWithQuery`/`atomWithMutation`은 여기서 정의하지 않음 → `hooks/`에서 정의
- 여러 컴포넌트·훅이 공유하는 상태만 atom으로 정의
- 단일 컴포넌트 전용 상태는 atom 금지 → `useState` 사용
- named export만

```typescript
// admin/src/store/userUI.ts
import { atom } from 'jotai';

export const selectedUserAtom = atom<number | null>(null);
export const userSearchKeywordAtom = atom<string>('');
```

### 공통 상태

위치: `shared/store/auth.ts`

- 인증 관련 상태 (userAtom, isAuthenticatedAtom, selectedGroupAtom 등)
- 양쪽 앱에서 `@shared/store/auth`로 import

---

## API 상태 — jotai-tanstack-query

### 위치 및 파일 패턴

- 위치: `{app}/src/hooks/use{Domain}Data.ts`
- `useQuery`/`useMutation` 직접 import 절대 금지
- 반드시 `atomWithQuery`/`atomWithMutation` 사용
- named export만

### atom 네이밍

- API 함수명 + `Atom` (예: `getUserListAtom`, `createUserAtom`, `deleteUserAtom`)

### queryKey 네이밍

- 목록: `['{domain}s']` (예: `['users']`)
- 단건: `['{domain}', id]` (예: `['user', id]`)

### atomWithQuery 패턴

```typescript
import { atomWithQuery } from 'jotai-tanstack-query';
import { getUserList } from '@/api/user';

export const getUserListAtom = atomWithQuery(() => ({
  queryKey: ['users'],
  queryFn: getUserList,
}));
```

- `enabled` 조건: 데이터 흐름에 따라 필요 시 추가
- response data mapping이 필요한 경우 hook 내에서 수행

### atomWithMutation 패턴

- CUD mutation의 `onSuccess`에서 반드시 관련 query를 invalidate

```typescript
import { atomWithMutation } from 'jotai-tanstack-query';
import { queryClient } from '@shared/lib/queryClient';
import { createUser, deleteUser } from '@/api/user';

export const createUserAtom = atomWithMutation(() => ({
  mutationFn: createUser,
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['users'] });
  },
}));

export const deleteUserAtom = atomWithMutation(() => ({
  mutationFn: deleteUser,
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['users'] });
  },
}));

// ❌ 금지
// import { useQuery, useMutation } from '@tanstack/react-query'
```

---

## 컴포넌트에서 atom 사용

### Query (읽기) → `useAtomValue`

구조 분해 시 제네릭한 이름을 **도메인에 맞게 재정의**한다.

```typescript
// ✅ useAtomValue + 이름 재정의
const { data: users, isLoading: isUsersLoading, error: usersError } = useAtomValue(getUserListAtom);

// ❌ 제네릭한 이름 그대로 사용 금지
const { data, isLoading, error } = useAtomValue(getUserListAtom);
```

### Mutation (쓰기) → `useSetAtom`

```typescript
const { mutate: createUser } = useSetAtom(createUserAtom);
const { mutate: deleteUser } = useSetAtom(deleteUserAtom);
```

### 금지 패턴

```typescript
// ❌ useAtom 이중 구조 분해 금지
const [{ data, isLoading, error }] = useAtom(getUserListAtom);
```

---

## 핸들러 훅에서 API atom 소비

핸들러 훅(`use{Domain}Handler.ts`)에서 API atom을 import하여 사용한다.
분리 기준은 @.claude/rules/coding-standards.md "hooks/ 파일 분류" 참조.

```typescript
// admin/src/hooks/useUserTableHandler.ts
import { useSetAtom } from 'jotai';
import { deleteUserAtom } from '@/hooks/useUserData';

export const useUserTableHandler = () => {
  const { mutate: deleteUser } = useSetAtom(deleteUserAtom);

  const handleDelete = (id: number) => {
    deleteUser(id);
  };

  return { handleDelete };
};
```
