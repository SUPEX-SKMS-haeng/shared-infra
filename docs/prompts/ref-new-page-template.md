# [Template] 새 관리 페이지 구현 계획서

> **사용 방법**: `prompt-new-page.md` 지시문과 함께 이 문서 내용을 AI에게 컨텍스트로 제공한다.
> AI는 아래 양식의 `{ }` 부분을 채워 구체적인 구현 계획서를 제시하게 된다.
>
> **참고 문서**: 아키텍처 패턴 및 레이어별 역할 설명은 `docs/guidelines/frontend-code-patterns.md`를 참고한다.

---

> 아래 각 Step의 `{ }` 빈칸을 채워 계획서를 완성한 뒤, **사용자 확인을 받은 후** 코드 작성을 시작한다.
>
> **UI 우선 개발 (Mock 버전)**: API 연동을 나중으로 미룰 경우 Step 3(API 레이어)와 Step 5(Data 훅)를 각 Step 하단의 **"Mock 대체"** 안내로 대체한다. Store·핸들러 훅·컴포넌트 구조는 API 버전과 동일하게 유지해 API 전환 시 `use*Data.ts` 파일만 교체하면 된다.

### Step 0. 사전 리팩토링

> 기존 코드 중 충돌·중복이 예상되는 부분을 먼저 정리한다.

- 분리/이동이 필요한 파일 또는 타입: `{ }`
- 리팩토링 후 회귀 확인 항목: `{ }`
- 관련 없으면 이 Step 생략 가능.

**→ Step 0 내용을 정리한 뒤 사용자 확인을 받고 Step 1로 진행한다.**

---

### Step 1. 파일 구조 확정

> 신규·수정 파일을 표와 디렉터리 트리로 정리한다.

| 구분      | 파일 경로                              | 신규/수정 |
| --------- | -------------------------------------- | --------- |
| 타입      | `src/types/{domain}.ts`                | 신규      |
| API       | `src/api/{domain}.ts`                  | 신규      |
| Store     | `src/store/{domain}UI.ts`              | 신규      |
| 데이터 훅 | `src/hooks/use{Domain}Data.ts`         | 신규      |
| 핸들러 훅 | `src/hooks/use{Domain}TableHandler.ts` | 신규      |
| 컴포넌트  | `src/components/features/{domain}/`    | 신규      |
| 라우트    | `src/routes/AppRoutes.tsx`             | 수정      |

```text
src/
├── types/{domain}.ts
├── api/{domain}.ts
├── store/{domain}UI.ts
├── hooks/
│   ├── use{Domain}Data.ts
│   └── use{Domain}TableHandler.ts
└── components/features/{domain}/
    ├── {Domain}s.tsx
    ├── {Domain}ActionBar.tsx
    ├── {Domain}TableColumns.tsx
    ├── {Domain}DetailModal.tsx
    └── {Domain}FormModal.tsx
```

**→ Step 1 완료 후 사용자 확인을 받고 Step 2로 진행한다.**

---

### Step 2. 타입 정의 (`src/types/{domain}.ts`)

> 프론트엔드 도메인 타입과 API 응답 타입을 한 파일에 분리해 둔다.
> 참고: `src/types/user.ts`

```typescript
// ===== 프론트엔드 도메인 타입 (camelCase) =====
export type {Domain}Status = '활성' | '비활성';

export interface {Domain} {
  id: number;
  // { camelCase 필드 목록 }
  status: {Domain}Status;
  createdAt: string; // dayjs 포맷 적용
}

export interface Create{Domain}Form {
  // { 생성 폼 필드 목록 }
  isActive: boolean;
}

export interface Edit{Domain}Form extends Create{Domain}Form {
  id: number;
}

// ===== API 응답 타입 (인터셉터가 camelCase로 변환 후 기준, 매핑 입력 전용 — 컴포넌트에서 직접 import 금지) =====
export interface I{Domain}ItemResponse {
  id: number;
  // { camelCase 필드 목록 }
  isActive: boolean | null;
  createDt: string | null;
  updateDt: string | null;
}

export interface I{Domain}ListResponse {
  {domain}List: I{Domain}ItemResponse[];
  totalCount: number;
  nextOffset: number;
}
```

매핑 원칙:

- 인터셉터(`@shared/hooks/useAxiosInterceptor.ts`)가 응답을 자동으로 camelCase로 변환 → DTO 타입 필드는 camelCase로 작성
- `isActive → status: '활성' | '비활성'`
- `createDt → createdAt` (dayjs 포맷: `'YYYY-MM-DD HH:mm:ss'`)
- 변환 위치: `use{Domain}Data.ts`의 `queryFn`/`mutationFn` 안에서만 수행.

**→ Step 2 완료 후 사용자 확인을 받고 Step 3으로 진행한다.**

---

### Step 3. API 레이어 (`src/api/{domain}.ts`)

> axiosInstance 기반으로 엔드포인트 호출. 쿼리 파라미터는 `{ params }` 옵션으로 전달 (`qs` 불필요).
> 매핑 없이 raw 응답만 반환. 참고: `src/api/organization.ts`

```typescript
import type { I{Domain}ListResponse, I{Domain}ItemResponse } from '@/types/{domain}';
import { axiosInstance } from '@shared/lib/axios';

const URL_PREFIX = '{/auth/xxx 등 게이트웨이 경로}';

// 목록 조회: params는 { params }로 전달 (인터셉터가 snake_case + 직렬화 처리)
export const get{Domain}List = async (params: {
  offset?: number;
  limit?: number;
  // { 검색 파라미터, camelCase }
}) => {
  const { data } = await axiosInstance.get<I{Domain}ListResponse>(URL_PREFIX, { params });
  return data;
};

// 생성: body는 camelCase로 작성 (인터셉터가 snake_case로 변환)
export const create{Domain} = async (body: {
  // { camelCase 필드, 필수 }
  isActive: boolean;
}) => {
  const { data } = await axiosInstance.post<I{Domain}ItemResponse>(URL_PREFIX, body);
  return data;
};

// 수정
export const update{Domain} = async (
  id: number,
  body: { isActive?: boolean; /* { camelCase 필드, 모두 optional } */ }
) => {
  const { data } = await axiosInstance.patch<I{Domain}ItemResponse>(`${URL_PREFIX}/${id}`, body);
  return data;
};

// 삭제
export const delete{Domain} = async (id: number) => {
  await axiosInstance.delete(`${URL_PREFIX}/${id}`);
};
```

> **Mock 대체**: API 연동 전이라면 이 Step을 건너뛰고 `src/data/mock{Domain}.ts`를 생성한다.
>
> ```typescript
> // src/data/mock{Domain}.ts
> import type { {Domain} } from '@/types/{domain}';
>
> export const getMock{Domain}s = (): {Domain}[] => [
>   { id: 1, /* { 예시 필드 } */, status: '활성' },
>   // ...
> ];
> ```
>
> API 전환 시 이 파일을 삭제하고 Step 3 본문대로 `api/{domain}.ts`를 생성한다.

**→ Step 3 완료 후 사용자 확인을 받고 Step 4로 진행한다.**

---

### Step 4. Jotai Store (`src/store/{domain}UI.ts`)

> UI 상태 전용 atom만 선언. 서버 상태 절대 포함 금지.
> 참고: `src/store/userUI.ts`

```typescript
import { atom } from 'jotai';
import type { {Domain} } from '@/types/{domain}';

export const isCreateModalOpenAtom = atom(false);
export const isDetailModalOpenAtom = atom(false);
export const isEditModalOpenAtom   = atom(false);

export const selected{Domain}Atom  = atom<{Domain} | null>(null);
export const selectedIdsAtom        = atom<Set<number>>(new Set<number>());

export const searchFilterAtom = atom({
  searchCategory: '', // '{ 카테고리 필드명 }' | ''
  searchKeyword: '',
});

export const currentPageAtom = atom(1);

export const sortStateAtom = atom<{
  field: string | null;
  order: 'asc' | 'desc';
}>({ field: null, order: 'asc' });
```

**→ Step 4 완료 후 사용자 확인을 받고 Step 5로 진행한다.**

---

### Step 5. 데이터 훅 (`src/hooks/use{Domain}Data.ts`)

> atomWithQuery/atomWithMutation 사용. 응답 → 도메인 타입 매핑을 이 레벨에서 한 번만 수행.
> 참고: `src/hooks/useUserData.ts`

```typescript
import { atomWithQuery, atomWithMutation } from 'jotai-tanstack-query';
import dayjs from 'dayjs';
import { queryClient } from '@shared/lib/queryClient';
import {
  get{Domain}List,
  create{Domain},
  update{Domain},
  delete{Domain},
} from '@/api/{domain}';
import type {
  {Domain},
  Create{Domain}Form,
  Edit{Domain}Form,
  I{Domain}ItemResponse,
} from '@/types/{domain}';
import { {domain}ListParamsAtom } from '@/store/{domain}UI';

const {DOMAIN}_KEY = ['{domain}'];

// API 응답(camelCase) → 도메인 타입 매핑 함수
const mapItem = (item: I{Domain}ItemResponse): {Domain} => ({
  id: item.id,
  // { 필드 매핑 }
  status: item.isActive ? '활성' : '비활성',
  createdAt: item.createDt
    ? dayjs(item.createDt).format('YYYY-MM-DD HH:mm:ss')
    : '-',
});

// 목록 조회
export const get{Domain}ListAtom = atomWithQuery((get) => {
  const params = get({domain}ListParamsAtom);
  return {
    queryKey: [...{DOMAIN}_KEY, 'list', params],
    queryFn: async () => {
      const res = await get{Domain}List(params);
      return {
        items: (res.{domain}List ?? []).map(mapItem),
        total: res.totalCount ?? 0,
      };
    },
    staleTime: 0,
  };
});

// 생성
export const create{Domain}Atom = atomWithMutation(() => ({
  mutationKey: [...{DOMAIN}_KEY, 'create'],
  mutationFn: async (form: Create{Domain}Form): Promise<{Domain}> => {
    const res = await create{Domain}({
      // { camelCase 필드 그대로 전달 (인터셉터가 변환) }
      isActive: form.isActive,
    });
    return mapItem(res);
  },
  onSuccess: () => {
    void queryClient.invalidateQueries({ queryKey: [...{DOMAIN}_KEY, 'list'] });
  },
  onError: (error: unknown) => {
    console.error('{도메인명} 생성 실패:', error);
  },
}));

// 수정
export const update{Domain}Atom = atomWithMutation(() => ({
  mutationKey: [...{DOMAIN}_KEY, 'update'],
  mutationFn: async (form: Edit{Domain}Form): Promise<{Domain}> => {
    const res = await update{Domain}(form.id, {
      // { 변경 필드만 전달, camelCase }
      isActive: form.isActive,
    });
    return mapItem(res);
  },
  onSuccess: () => {
    void queryClient.invalidateQueries({ queryKey: [...{DOMAIN}_KEY, 'list'] });
  },
  onError: (error: unknown) => {
    console.error('{도메인명} 수정 실패:', error);
  },
}));

// 삭제
export const delete{Domain}Atom = atomWithMutation(() => ({
  mutationKey: [...{DOMAIN}_KEY, 'delete'],
  mutationFn: async (id: number): Promise<void> => {
    await delete{Domain}(id);
  },
  onSuccess: () => {
    void queryClient.invalidateQueries({ queryKey: [...{DOMAIN}_KEY, 'list'] });
  },
  onError: (error: unknown) => {
    console.error('{도메인명} 삭제 실패:', error);
  },
}));
```

> **Mock 대체**: API 연동 전이라면 `atomWithQuery` 대신 plain `atom`으로 구현한다.  
> 핸들러 훅과 컨테이너 코드는 동일하게 유지 — API 전환 시 이 파일만 교체한다.
>
> ```typescript
> // hooks/use{Domain}Data.ts (Mock 버전)
> import { atom } from 'jotai';
> import { {domain}ListParamsAtom } from '@/store/{domain}UI';
> import { getMock{Domain}s } from '@/data/mock{Domain}';
>
> // params atom에서 파생된 computed atom — 클라이언트 사이드 필터/페이지 처리
> export const get{Domain}ListAtom = atom((get) => {
>   const params = get({domain}ListParamsAtom);
>   const allItems = getMock{Domain}s();
>   const filtered = allItems.filter((item) => {
>     if (!params.searchKeyword) return true;
>     // { 검색 필터 로직 }
>     return true;
>   });
>   return {
>     items: filtered.slice(params.offset, params.offset + params.limit),
>     total: filtered.length,
>   };
> });
>
> // mutation은 Mock 단계에서 생략 (핸들러 훅에서 직접 상태만 변경)
> ```
>
> API 전환 시: 이 파일 전체를 `atomWithQuery`/`atomWithMutation` 버전으로 교체하고 `data/mock{Domain}.ts` 삭제.

**→ Step 5 완료 후 사용자 확인을 받고 Step 6으로 진행한다.**

---

### Step 6. 핸들러 훅 (`src/hooks/use{Domain}TableHandler.ts`)

> **UI atom은 이 훅에서만 구독**한다. 컨테이너 컴포넌트는 이 훅의 반환값만 사용한다.
> 참고: `src/hooks/useUserTableHandler.ts`

제공할 핸들러 목록:

- `handleSearch` — searchFilter → params 반영, 페이지·선택 초기화
- `handlePageChange` — `offset = (page - 1) * limit`, currentPage 갱신
- `handleSort` — UI 필드명 → API 필드명 매핑 후 params 갱신
- `handleToggleSelect(id)` / `handleToggleSelectAll(ids)`
- `handleCreate(form: Create{Domain}Form)` — createAtom.mutateAsync → 모달 닫기
- `handleEdit(form: Edit{Domain}Form)` — updateAtom.mutateAsync → 모달 닫기
- `handleDelete()` — `confirm()` 후 deleteAtom.mutateAsync, 모달 닫기
- `handleBulkDelete()` — selectedIds 기준 반복 단건 삭제 (bulk API 미제공 시)
- `handleRowClick(item: {Domain})` — selected{Domain} 설정 + 상세 모달 열기
- `handleEditClick()` — 상세 모달 닫기 + 수정 모달 열기

반환 구조 예시:

```typescript
return {
  // 데이터
  items, total, isLoading, isError,
  // UI 상태
  searchFilter, currentPage, selectedIds, sortState,
  selected{Domain}, isCreateModalOpen, isDetailModalOpen, isEditModalOpen,
  // 핸들러
  handleSearch, handlePageChange, handleSort,
  handleToggleSelect, handleToggleSelectAll,
  handleCreate, handleEdit, handleDelete, handleBulkDelete,
  handleRowClick, handleEditClick,
  // 모달 닫기
  closeDetailModal: () => setIsDetailModalOpen(false),
  closeEditModal:   () => setIsEditModalOpen(false),
  closeCreateModal: () => setIsCreateModalOpen(false),
};
```

**→ Step 6 완료 후 사용자 확인을 받고 Step 7로 진행한다.**

---

### Step 7. 컴포넌트 (`src/components/features/{domain}/`)

> 공통 `ui/`(DataTable, Pagination, SearchBar, ActionBar)를 재사용한다.
> SearchBar·ActionBar는 이 단계에서 함께 구현한다 (별도 단계 불필요).
> 참고: `src/components/features/users/` 전체 구조

| 파일명                     | 역할                                | 참고                   |
| -------------------------- | ----------------------------------- | ---------------------- |
| `{Domain}TableColumns.tsx` | `ColumnDef<{Domain}>[]` 정의        | `UserTableColumns.tsx` |
| `{Domain}ActionBar.tsx`    | 총 N건, 선택 M건, 등록 버튼         | `UserActionBar.tsx`    |
| `{Domain}DetailModal.tsx`  | 라벨-값 상세 + 수정/삭제 버튼       | `UserDetailModal.tsx`  |
| `{Domain}FormModal.tsx`    | `mode='create'\|'edit'` 등록/수정   | `UserFormModal.tsx`    |
| `{Domain}s.tsx`            | 페이지 조합. UI atom 직접 구독 금지 | `Users.tsx`            |

검색 카테고리 드롭다운 옵션:

```typescript
const SEARCH_OPTIONS = [
  { value: "", label: "선택(전체)" },
  { value: "{field1}", label: "{레이블1}" },
  { value: "{field2}", label: "{레이블2}" },
];
```

`{Domain}s.tsx` 구조 (얇게 유지):

```tsx
const {Domain}s = () => {
  const {
    items, total, isLoading,
    searchFilter, currentPage, selectedIds,
    selected{Domain}, isCreateModalOpen, isDetailModalOpen, isEditModalOpen,
    handleSearch, handlePageChange, handleRowClick,
    handleCreate, handleEdit, handleDelete, handleBulkDelete,
    handleToggleSelect, handleToggleSelectAll,
    closeCreateModal, closeDetailModal, closeEditModal,
  } = use{Domain}TableHandler();

  return (
    <>
      <SearchBar searchFilter={searchFilter} onSearch={handleSearch} options={SEARCH_OPTIONS} />
      <{Domain}ActionBar
        total={total}
        selectedCount={selectedIds.size}
        onCreateClick={() => { /* isCreateModalOpen 열기 */ }}
      />
      <DataTable
        data={items}
        columns={{domain}TableColumns}
        selectedIds={selectedIds}
        onToggleSelect={handleToggleSelect}
        onToggleSelectAll={handleToggleSelectAll}
        onRowClick={handleRowClick}
        isLoading={isLoading}
      />
      <Pagination currentPage={currentPage} total={total} onPageChange={handlePageChange} />
      {/* 모달 */}
      {isCreateModalOpen && (
        <{Domain}FormModal mode="create" onClose={closeCreateModal} onSubmit={handleCreate} />
      )}
      {isDetailModalOpen && selected{Domain} && (
        <{Domain}DetailModal
          item={selected{Domain}}
          onClose={closeDetailModal}
          onEditClick={handleEditClick}
          onDeleteClick={handleDelete}
        />
      )}
      {isEditModalOpen && selected{Domain} && (
        <{Domain}FormModal mode="edit" item={selected{Domain}} onClose={closeEditModal} onSubmit={handleEdit} />
      )}
    </>
  );
};
```

**→ Step 7 완료 후 사용자 확인을 받고 Step 8로 진행한다.**

---

### Step 8. 라우트 연결 (`src/routes/AppRoutes.tsx`)

```typescript
import {Domain}sPage from '@/components/features/{domain}/{Domain}s';

// 기존 placeholder → 실제 컴포넌트로 교체
<Route path='{path}' element={<{Domain}sPage />} />
```

**→ Step 8 완료 후 사용자 확인을 받고 Step 9(테스트)로 진행한다.**

---

### Step 9. 브라우저 테스트 시나리오

> 사전 준비: `localStorage.setItem('accessToken', '<token>')` 실행 후 새로고침 없이 해당 탭에서 진행.

| #   | 시나리오                                  | 기대 결과                                            |
| --- | ----------------------------------------- | ---------------------------------------------------- |
| 1   | 초기 상태 — 페이지 진입                   | ✅ 목록 API 호출 성공, 총 N건 표시, 컬럼 정상 렌더링 |
| 2   | 검색 — 카테고리 선택 + 키워드 입력 + 조회 | ✅ 필터 결과로 목록·건수 갱신                        |
| 3   | 페이지네이션 — 다음 페이지 이동           | ✅ offset 변경 후 API 재호출, 선택 초기화            |
| 4   | 등록 — 등록 버튼 → 폼 입력 → 저장         | ✅ POST 호출, 모달 닫힘, 목록 즉시 갱신              |
| 5   | 상세 — 행 클릭                            | ✅ 상세 모달 열림, 모든 필드 정상 표시               |
| 6   | 수정 — 상세 → 수정 → 저장                 | ✅ PATCH 호출, 목록 갱신                             |
| 7   | 단건 삭제 — 상세 → 삭제                   | ✅ `confirm()` 후 DELETE 호출, 목록에서 제거         |
| 8   | 일괄 삭제 — 복수 선택 → 휴지통            | ✅ 선택 건수만큼 DELETE 반복, 목록 갱신              |
| 9   | 에러 케이스 — 토큰 없이 접속              | ✅ 401 → 로그인 리다이렉트, 403 → 에러 메시지        |

**→ Step 9 완료 후 사용자 확인을 받고 Step 10(체크리스트)으로 진행한다.**

---

### Step 10. 연동 확인 체크리스트

| #                                 | 구분     | 확인 항목                                                     | 완료 |
| --------------------------------- | -------- | ------------------------------------------------------------- | :--: |
| **— Step 0: 사전 리팩토링 —**     |          |                                                               |      |
| 1                                 | 리팩토링 | 기존 코드 충돌 제거 및 회귀 없음 확인                         |  ☐   |
| **— Step 1~2: 타입 —**            |          |                                                               |      |
| 2                                 | 타입     | `I{Domain}ItemResponse`, `I{Domain}ListResponse` 포함         |  ☐   |
| 3                                 | 타입     | DTO 타입(`I*Response`)은 인터셉터 변환 후 camelCase, 화면 타입도 camelCase |  ☐   |
| **— Step 3: API —**               |          |                                                               |      |
| 4                                 | API      | `URL_PREFIX` 올바름, axiosInstance + `{ params }` 패턴 사용   |  ☐   |
| 5                                 | API      | 응답 매핑 없이 raw 반환 (매핑은 훅에서만) / Mock이면 `data/mock*.ts` 생성 |  ☐   |
| **— Step 4~6: Store·Hook —**      |          |                                                               |      |
| 6                                 | Store    | UI 상태 atom만 선언 (서버 상태 포함 금지)                     |  ☐   |
| 7                                 | Hook     | 매핑(`isActive→status`, dayjs)이 `queryFn` 안에서만 / Mock이면 `get*ListAtom` plain atom | ☐ |
| 8                                 | Hook     | 핸들러 훅만 UI atom을 구독하며, UI 상태 값·핸들러를 함께 반환 |  ☐   |
| 9                                 | Hook     | onSuccess에서 `invalidateQueries` 호출됨                      |  ☐   |
| **— Step 7~8: 컴포넌트·라우트 —** |          |                                                               |      |
| 10                                | 컴포넌트 | `{Domain}s.tsx`에서 UI atom 직접 구독 없음                    |  ☐   |
| 11                                | 컴포넌트 | DataTable, Pagination 등 공통 ui/ 컴포넌트 재사용             |  ☐   |
| 12                                | 라우트   | AppRoutes placeholder → 실제 컴포넌트 교체                    |  ☐   |
| **— Step 9: 테스트 —**            |          |                                                               |      |
| 13                                | 테스트   | 시나리오 1(초기) 통과                                         |  ☐   |
| 14                                | 테스트   | 시나리오 2(검색) 통과                                         |  ☐   |
| 15                                | 테스트   | 시나리오 3(페이지네이션) 통과                                 |  ☐   |
| 16                                | 테스트   | 시나리오 4(등록) 통과                                         |  ☐   |
| 17                                | 테스트   | 시나리오 5(상세) 통과                                         |  ☐   |
| 18                                | 테스트   | 시나리오 6(수정) 통과                                         |  ☐   |
| 19                                | 테스트   | 시나리오 7(단건 삭제) 통과                                    |  ☐   |
| 20                                | 테스트   | 시나리오 8(일괄 삭제) 통과                                    |  ☐   |
| 21                                | 테스트   | 시나리오 9(에러) 통과                                         |  ☐   |

---

## 참고: 기존 코드 대응표

| 사용자 관리 (참고)                    | {도메인명} 관리 (신규)                       |
| ------------------------------------- | -------------------------------------------- |
| `types/user.ts`                       | `types/{domain}.ts`                          |
| `api/user.ts`                         | `api/{domain}.ts`                            |
| `store/userUI.ts`                     | `store/{domain}UI.ts`                        |
| `hooks/useUserData.ts`                | `hooks/use{Domain}Data.ts`                   |
| `hooks/useUserTableHandler.ts`        | `hooks/use{Domain}TableHandler.ts`           |
| `features/users/UserActionBar.tsx`    | `features/{domain}/{Domain}ActionBar.tsx`    |
| `features/users/UserTableColumns.tsx` | `features/{domain}/{Domain}TableColumns.tsx` |
| `features/users/UserDetailModal.tsx`  | `features/{domain}/{Domain}DetailModal.tsx`  |
| `features/users/UserFormModal.tsx`    | `features/{domain}/{Domain}FormModal.tsx`    |
| `features/users/Users.tsx`            | `features/{domain}/{Domain}s.tsx`            |
