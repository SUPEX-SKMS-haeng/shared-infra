# Frontend 코드 패턴 레퍼런스

본 문서는 `frontends/admin/` 내에 구현된 실제 코드의 아키텍처 패턴을 설명합니다.  
새로운 코드를 작성할 때 이 패턴을 준수해야 합니다.

> 새 페이지 구현 절차(Step-by-Step)는 `docs/prompts/ref-new-page-template.md`를 참고하세요.

---

## 1. 아키텍처 개요

**Jotai** + **Jotai-TanStack-Query** 조합을 기반으로 상태를 관리합니다.  
로직을 레이어별로 분리하고, 이를 컴포넌트로 주입하는 **레이어드 아키텍처** 패턴을 따릅니다.

- **`types/`**: 화면용 도메인 타입 + API 응답 타입(DTO)을 한 파일에 분리 선언
- **`api/`**: axios 기반 순수 HTTP 통신 함수 (매핑 없이 raw 응답 반환)
- **`store/*UI.ts`**: 클라이언트 전용 UI 상태 atom (모달, 페이지, 선택, 검색 등)
- **`hooks/use*Data.ts`**: `atomWithQuery`/`atomWithMutation` — 서버 상태 + DTO 매핑
- **`hooks/use*TableHandler.ts`**: UI atom setter + mutation을 엮은 이벤트 핸들러 모음
- **`components/features/`**: 도메인 특화 컴포넌트 및 최종 조립 컨테이너

---

## 2. 레이어별 역할 및 구조 트리

```text
src/
├── types/             ① 도메인 타입 & API 응답 타입(DTO) 분리 선언
├── api/               ② 순수 HTTP 통신 (axios), raw 응답 반환
├── store/             ③ 클라이언트 UI 상태 (Jotai atom, *UI.ts)
├── hooks/
│   ├── use*Data.ts    ④ 서버 상태 (atomWithQuery/atomWithMutation + DTO 매핑)
│   └── use*TableHandler.ts  ⑤ 이벤트 핸들러 (UI atom setter + mutation 조합)
└── components/
    ├── ui/            ⑥ 공통 UI (DataTable, SearchBar, Pagination 등)
    └── features/xxx/  ⑦ 도메인 컴포넌트 + 최종 조립 컨테이너 (*s.tsx)
```

---

## 3. 패턴별 실제 코드 레퍼런스

### 3.1 타입 정의 패턴 (`types/`)

화면 표시용 **뷰 모델**과 API 원본 **DTO**를 같은 파일 안에서 분리 선언합니다.

> **케이스 변환 자동화**: `@shared/hooks/useAxiosInterceptor.ts`가 axios 인터셉터를 통해  
> - **요청** (`params`, `body`): camelCase → snake_case 자동 변환  
> - **응답** (`data`): snake_case → camelCase 자동 변환  
>
> 따라서 프론트엔드 코드(API 함수, DTO 타입, 뷰 모델 모두)는 **camelCase로만 작성**합니다.

```typescript
// types/organization.ts

// ===== 화면 표시용 도메인 타입 =====
export type OrganizationStatus = '활성' | '비활성';

export interface Organization {
  id: number | string;
  name: string;
  description: string;
  status: OrganizationStatus;
  createdAt: string;
}

export interface CreateOrganizationForm {
  name: string;
  description: string;
  isActive: boolean;        // Form 내부는 boolean, 화면 표시는 status 문자열
}

export interface EditOrganizationForm extends CreateOrganizationForm {
  id: number | string;
}

// ===== API 응답 DTO (인터셉터가 camelCase로 변환한 후 기준, 매핑 입력 전용) =====
// 컴포넌트에서 직접 import 금지. hooks/use*Data.ts 에서만 사용.
export interface IOrganizationResponse {
  id: number | null;
  name: string | null;
  description: string | null;
  isActive: boolean | null;   // 백엔드 is_active → 인터셉터가 isActive로 변환
  updateDt: string | null;    // 백엔드 update_dt → updateDt
  createDt: string | null;    // 백엔드 create_dt → createDt
}

export interface IOrganizationListResponse {
  organizationList: IOrganizationResponse[];  // 백엔드 organization_list → organizationList
  totalCount: number;
  nextOffset: number;
}
```

**DTO → 뷰 모델 변환 규칙**

| DTO 필드 (camelCase) | 뷰 모델 필드 | 변환 방식 |
|---|---|---|
| `isActive: boolean \| null` | `status: '활성' \| '비활성'` | `true → '활성'`, `false → '비활성'` |
| `createDt: string \| null` | `createdAt: string` | dayjs 포맷 또는 `?? ''` |
| 동일 필드명 | 동일 | null 방어: `res.name ?? ''` |

---

### 3.2 API 구현 패턴 (`api/`)

`axiosInstance`에 **`{ params }` 옵션 객체**로 쿼리 파라미터를 전달합니다.  
`qs.stringify`를 직접 사용하지 않습니다 — `useAxiosInterceptor`가 `params`를 snake_case로 변환하고 직렬화를 처리합니다.

Request 타입은 별도 인터페이스 없이 **함수 인자에 인라인으로 정의**합니다.  
반환 타입 `Promise<T>`는 생략하고 TypeScript 추론을 활용합니다.  
**매핑 없이 raw DTO만 반환**합니다 (매핑은 `use*Data.ts`에서만 수행).

```typescript
// api/organization.ts
import type { IOrganizationListResponse, IOrganizationResponse } from '@/types/organization';
import { axiosInstance } from '@shared/lib/axios';

const URL_PREFIX = '/auth/organization';

// 목록 조회: params 객체를 { params } 로 전달 (인터셉터가 snake_case + 직렬화 처리)
export const getOrganizationList = async (params: {
  offset: number;
  limit: number;
  searchCategory?: string;
  searchKeyword?: string;
  sort?: string;
  order?: 'asc' | 'desc';
}) => {
  const { data } = await axiosInstance.get<IOrganizationListResponse>(
    URL_PREFIX,
    { params }
  );
  return data;
};

// 상세 조회
export const getOrganization = async (
  orgId: number | string,
  includeMembers = false
) => {
  const { data } = await axiosInstance.get<IOrganizationResponse>(
    `${URL_PREFIX}/detail/${orgId}`,
    { params: { includeMembers } }
  );
  return data;
};

// 생성: body는 camelCase로 작성 (인터셉터가 snake_case로 변환)
export const createOrganization = async (body: {
  name: string;
  description: string;
  isActive: boolean;
  members?: { userId: number; role: string }[] | null;
}) => {
  const { data } = await axiosInstance.post<IOrganizationResponse>(URL_PREFIX, body);
  return data;
};

// 수정
export const updateOrganization = async (
  orgId: number | string,
  body: { name?: string; description?: string; isActive?: boolean }
): Promise<IOrganizationResponse> => {
  const { data } = await axiosInstance.patch<IOrganizationResponse>(
    `${URL_PREFIX}/${orgId}`,
    body
  );
  return data;
};

// 삭제
export const deleteOrganization = async (orgId: number | string) => {
  const { data } = await axiosInstance.delete(`${URL_PREFIX}/${orgId}`);
  return data;
};
```

---

### 3.3 UI 전용 상태 (`store/*UI.ts`)

**클라이언트 화면 상태만** 담습니다. 서버 상태 절대 포함 금지.

```typescript
// store/userUI.ts
import { atom } from 'jotai';
import type { User } from '@/types/user';

// 모달 상태
export const isCreateModalOpenAtom = atom(false);
export const isDetailModalOpenAtom = atom(false);
export const isEditModalOpenAtom   = atom(false);

// 선택된 항목
export const selectedUserAtom = atom<User | null>(null);

// 체크박스 선택 (row index 기준)
export const selectedIdsAtom = atom<Set<number>>(new Set<number>());

// 페이지네이션
export const currentPageAtom = atom(1);

// 정렬 상태
export const sortStateAtom = atom<{ field: string | null; order: 'asc' | 'desc' }>({
  field: 'user_id',
  order: 'asc',
});

// 목록 조회 파라미터 (searchKeyword/searchCategory/order/sort/role 등 포함)
export const userListParamsAtom = atom({
  offset: 0,
  limit: 10,
  searchKeyword: '',
  searchCategory: '' as string,
  order: 'asc' as 'asc' | 'desc',
  sort: 'user_id',
  role: '',
  isActive: null as boolean | null,
});
```

---

### 3.4 서버 상태 훅 (`hooks/use*Data.ts`)

`atomWithQuery` / `atomWithMutation` 사용.  
**DTO → 뷰 모델 매핑은 반드시 이 레벨에서 한 번만** 수행합니다.

```typescript
// hooks/useOrganizationData.ts
import { atomWithQuery, atomWithMutation } from 'jotai-tanstack-query';
import { queryClient } from '@shared/lib/queryClient';
import { getOrganizationList, createOrganization, updateOrganization } from '@/api/organization';
import { organizationListParamsAtom } from '@/store/organizationUI';
import type { Organization, IOrganizationResponse } from '@/types/organization';

const ORGANIZATION_DATA_KEY = ['organization'];

// DTO → 뷰 모델 매핑 (이 파일 안에서만 사용)
const mapOrgResponse = (res: IOrganizationResponse): Organization => ({
  id: res.id ?? '',
  name: res.name ?? '',
  description: res.description ?? '',
  status: res.isActive ? '활성' : '비활성',
  createdAt: res.createDt ?? '',
});

// 목록 조회
export const getOrganizationListAtom = atomWithQuery((get) => {
  const params = get(organizationListParamsAtom);   // ← store의 UI 파라미터 구독
  return {
    queryKey: [...ORGANIZATION_DATA_KEY, 'list', params],
    queryFn: async () => {
      const res = await getOrganizationList({ ...params });
      return {
        organizations: (res.organizationList ?? []).map(mapOrgResponse),
        total: res.totalCount ?? 0,
      };
    },
    staleTime: 0,
  };
});

// 생성
export const createOrganizationAtom = atomWithMutation(() => ({
  mutationKey: [...ORGANIZATION_DATA_KEY, 'create'],
  mutationFn: async (form: CreateOrganizationForm): Promise<Organization> => {
    const res = await createOrganization({
      name: form.name,
      description: form.description,
      isActive: form.isActive,
    });
    return mapOrgResponse(res);
  },
  onSuccess: () => {
    void queryClient.invalidateQueries({ queryKey: [...ORGANIZATION_DATA_KEY, 'list'] });
  },
}));
```

---

### 3.5 핸들러 훅 패턴 (`hooks/use*TableHandler.ts`)

**핸들러 훅의 핵심 역할**: UI atom과 서버 mutation atom을 **이 훅 안에서만 구독**하고,  
그 결과로 만들어진 **UI 상태 값 + 이벤트 핸들러 묶음**을 컨테이너에 반환하는 것입니다.  
컨테이너 컴포넌트는 `useAtom`/`useSetAtom`으로 UI atom을 직접 구독하지 않고,  
오직 서버 데이터 atom(`get*ListAtom`)만 직접 구독합니다.

```typescript
// hooks/useUserTableHandler.ts
import { useAtom, useSetAtom } from 'jotai';
import { createUserAtom, updateUserAtom, deleteUserAtom, deleteBulkUsersAtom } from './useUserData';
import {
  isCreateModalOpenAtom, isDetailModalOpenAtom, isEditModalOpenAtom,
  selectedUserAtom, selectedIdsAtom, currentPageAtom, sortStateAtom, userListParamsAtom,
} from '@/store/userUI';
import type { CreateUserForm, EditUserForm, User } from '@/types/user';
import type { SearchBarFilter } from '@/types/search';

export const useUserTableHandler = () => {
  // mutation atoms
  const [createMutation] = useAtom(createUserAtom);
  const [updateMutation] = useAtom(updateUserAtom);
  const [deleteMutation] = useAtom(deleteUserAtom);
  const [deleteBulkMutation] = useAtom(deleteBulkUsersAtom);

  // UI atom setters
  const setParams        = useSetAtom(userListParamsAtom);
  const setIsCreateModalOpen = useSetAtom(isCreateModalOpenAtom);
  const setIsDetailModalOpen = useSetAtom(isDetailModalOpenAtom);
  const setIsEditModalOpen   = useSetAtom(isEditModalOpenAtom);
  const [selectedUser, setSelectedUser] = useAtom(selectedUserAtom);
  const [selectedIds, setSelectedIds]   = useAtom(selectedIdsAtom);
  const setCurrentPage   = useSetAtom(currentPageAtom);
  const [sortState, setSortState] = useAtom(sortStateAtom);

  const handleSearch = ({ searchCategory, searchKeyword }: SearchBarFilter) => {
    setParams((prev) => ({ ...prev, searchKeyword, searchCategory, offset: 0 }));
    setCurrentPage(1);
    setSelectedIds(new Set());
  };

  const handlePageChange = (page: number) => {
    setParams((prev) => ({ ...prev, offset: (page - 1) * prev.limit }));
    setCurrentPage(page);
    setSelectedIds(new Set());
  };

  const handleSort = (field: string) => {
    const newOrder = sortState.field === field && sortState.order === 'asc' ? 'desc' : 'asc';
    setSortState({ field, order: newOrder });
    setParams((prev) => ({ ...prev, sort: field, order: newOrder, offset: 0 }));
    setCurrentPage(1);
    setSelectedIds(new Set());
  };

  const handleCreateUser = async (formData: CreateUserForm) => {
    await createMutation.mutateAsync(formData);
    setIsCreateModalOpen(false);
  };

  const handleRowClick = (user: User) => {
    setSelectedUser(user);
    setIsDetailModalOpen(true);
  };

  // ... handleEditUser, handleDeleteUser, handleBulkDelete, handleEditClick 등

  return {
    handleSearch, handlePageChange, handleSort,
    handleToggleSelect, handleToggleSelectAll,
    handleCreateUser, handleEditUser, handleDeleteUser, handleBulkDelete,
    handleRowClick, handleEditClick,
  };
};
```

**핸들러 훅이 담당해야 할 책임 목록**

| 핸들러 | 역할 |
|---|---|
| `handleSearch` | searchKeyword/Category → params 반영, 페이지·선택 초기화 |
| `handlePageChange` | `offset = (page-1) * limit`, currentPage 갱신, 선택 초기화 |
| `handleSort` | UI 필드명 → API 필드명 매핑 후 params 갱신 |
| `handleToggleSelect(idx)` | 체크박스 단건 토글 |
| `handleToggleSelectAll(count)` | 전체 선택/해제 |
| `handleCreate(form)` | mutateAsync → 모달 닫기 |
| `handleEdit(form)` | mutateAsync → 모달 닫기 |
| `handleDelete()` | confirm → mutateAsync → 모달·선택 초기화 |
| `handleBulkDelete(items)` | confirm → 일괄/단건 분기 → 선택 초기화 |
| `handleRowClick(item)` | selectedItem 설정 + 상세 모달 열기 |
| `handleEditClick()` | 상세 모달 닫기 + 수정 모달 열기 |

---

### 3.6 컨테이너 패턴 (`components/features/*/`)

컨테이너는 **렌더링에만 집중**합니다.

- **데이터**: `useAtomValue(get*ListAtom)` 로 서버 데이터 구독
- **UI 상태값**: store의 atom을 직접 `useAtom` / `useAtomValue` 로 구독
- **이벤트**: `use*TableHandler()` 가 반환하는 핸들러만 사용
- **비즈니스 로직 함수를 컨테이너 안에 직접 정의하지 않습니다.**

```tsx
// components/features/deployments/Deployments.tsx (요약)
const DeploymentsPage = () => {
  // 1. 서버 데이터 구독
  const { data, isLoading, isError } = useAtomValue(getDeploymentListAtom);

  // 2. UI 상태 직접 구독 (읽기)
  const [isCreateModalOpen, setIsCreateModalOpen] = useAtom(isCreateModalOpenAtom);
  const [selectedDeployment, setSelectedDeployment] = useAtom(selectedDeploymentAtom);
  const [selectedIds] = useAtom(selectedIdsAtom);
  const [currentPage]  = useAtom(currentPageAtom);
  const [sortState]    = useAtom(sortStateAtom);

  // 3. 이벤트 핸들러 (핸들러 훅에서만)
  const {
    handleSearch, handlePageChange, handleSort,
    handleToggleSelect, handleToggleSelectAll,
    handleCreateDeployment, handleEditDeployment,
    handleDeleteDeployment, handleBulkDelete,
    handleRowClick, handleEditClick,
  } = useDeploymentTableHandler();

  return (
    <>
      <SearchBar type="deployments" onSearch={handleSearch} />
      <DataTable<Deployment>
        data={data?.deployments ?? []}
        columns={DeploymentTableColumns}
        selectedIds={selectedIds}
        sortBy={sortState.field}
        sortOrder={sortState.order}
        onSort={handleSort}
        onToggleSelect={handleToggleSelect}
        onRowClick={handleRowClick}
        isLoading={isLoading}
      />
      <Pagination
        currentPage={currentPage}
        totalPages={Math.ceil((data?.total ?? 0) / 10)}
        onPageChange={handlePageChange}
      />
      {/* 모달은 UI atom 열림 여부로 제어 */}
    </>
  );
};
```

---

## 4. 공통 UI 컴포넌트 사용 가이드 (`components/ui/`)

### 4.1 SearchBar

`type` 파라미터로 도메인별 검색 옵션을 분기합니다.

```tsx
<SearchBar
  type="users"         // 'users' | 'organizations' | 'members' | 'deployments' | ...
  onSearch={handleSearch}   // ({ searchCategory, searchKeyword }) => void
/>
```

### 4.2 DataTable

컬럼 정의(`ColumnDef<T>[]`)는 별도 파일(`*TableColumns.tsx`)로 분리합니다.

```tsx
<DataTable<User>
  data={users}
  columns={UserTableColumns}
  rowKey={(u) => u.loginId}
  selectedIds={selectedIds}      // Set<number> (row index 기준)
  onToggleSelect={handleToggleSelect}
  onToggleSelectAll={() => handleToggleSelectAll(users.length)}
  sortBy={sortState.field}
  sortOrder={sortState.order}
  onSort={handleSort}
  onRowClick={handleRowClick}
  isLoading={isLoading}
  isError={isError}
/>
```

---

_패턴/철학 레퍼런스 문서입니다. 구현 Step-by-Step은 `docs/prompts/ref-new-page-template.md`를 참고하세요._
