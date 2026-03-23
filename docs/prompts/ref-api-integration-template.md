# [Template] 기존 화면 API 연동 구현 계획서

> **사용 방법**: `prompt-api-integration.md` 지시문과 함께 이 문서 내용을 AI에게 컨텍스트로 제공한다.
> AI는 아래 양식의 `{ }` 부분을 채워 구체적인 구현 계획서를 제시하게 된다.
>
> **참고 문서**: 아키텍처 패턴 및 DTO/매핑 규칙은 `docs/guidelines/frontend-code-patterns.md`를 참고한다.

---

> 아래 각 Step의 `{ }` 빈칸을 채우거나 채울 것을 요청해 계획서를 완성한 뒤, **사용자 확인을 받은 후** 코드 작성을 시작한다.

### Step 0. 파일 구조 (수정 대상 확정)

| 구분      | 파일 경로                              | 작업 내용                |
| --------- | -------------------------------------- | ------------------------ |
| 타입      | `src/types/{domain}.ts`                | API 응답 인터페이스 추가 |
| API       | `src/api/{domain}.ts`                  | mock 제거 후 실제 구현   |
| 데이터 훅 | `src/hooks/use{Domain}Data.ts`         | atomWithQuery 교체       |
| 핸들러 훅 | `src/hooks/use{Domain}TableHandler.ts` | params 스펙 정합성 점검  |

**→ Step 0 완료 후 사용자 확인을 받고 Step 1로 진행한다.**

---

### Step 1. 게이트웨이 라우팅 정리

> URL_PREFIX 결정 근거를 명확히 한다.

| 프론트 URL_PREFIX | 게이트웨이 규칙 | 백엔드 서비스 | 실제 도달 경로 |
| ----------------- | --------------- | ------------- | -------------- |
| `{ }`             | `{ }`           | `{ }`         | `{ }`          |

**→ Step 1 완료 후 사용자 확인을 받고 Step 2로 진행한다.**

---

### Step 2. 타입 추가 (`src/types/{domain}.ts`)

> 기존 화면 타입은 유지하고, API 응답 인터페이스만 추가한다.  
> 응답 타입은 **인터셉터가 camelCase로 변환한 이후 형태**를 기준으로 정의한다.

```typescript
// 기존 {Domain}, Create{Domain}Form, Edit{Domain}Form 유지 (수정 금지)

// ===== 추가: API 응답 타입 (인터셉터 camelCase 변환 이후 기준, 매핑 입력 전용 — 컴포넌트에서 import 금지) =====
export interface I{Domain}Response {
  id: number | null;
  // { camelCase 필드 목록 }
  isActive: boolean | null;
  updateDt: string | null;
  createDt: string | null;
}

export interface I{Domain}ListResponse {
  {domain}List: I{Domain}Response[];
  totalCount: number;
  nextOffset: number;
}
```

매핑 규칙:

| 백엔드 필드 (snake_case) | 인터셉터/DTO 필드 (camelCase) | 화면 필드 | 변환 방식                           |
| ------------------------ | ----------------------------- | --------- | ----------------------------------- |
| `is_active`              | `isActive`                    | `status`  | `true → '활성'`, `false → '비활성'` |
| `create_dt`              | `createDt`                    | `createdAt` | dayjs 포맷 또는 그대로            |
| `{ }`                    | `{ }`                         | `{ }`     | `{ }`                               |

**→ Step 2 완료 후 사용자 확인을 받고 Step 3으로 진행한다.**

---

### Step 3. API 레이어 (`src/api/{domain}.ts`)

> mock 제거. `axiosInstance` 기반으로 교체. 쿼리 파라미터는 `{ params }` 옵션으로 전달하고,  
> `@shared/hooks/useAxiosInterceptor.ts`가 `params`/`data`를 snake_case로 변환 및 직렬화한다.  
> 매핑 없이 raw DTO만 반환한다.

```typescript
import type { I{Domain}ListResponse, I{Domain}Response } from '@/types/{domain}';
import { axiosInstance } from '@shared/lib/axios';

const URL_PREFIX = '{ /auth/organization 등 }';

export const get{Domain}List = async (params: {
  offset: number;
  limit: number;
  searchCategory?: string;
  searchKeyword?: string;
}): Promise<I{Domain}ListResponse> => {
  const { data } = await axiosInstance.get<I{Domain}ListResponse>(URL_PREFIX, {
    params,
  });
  return data;
};

export const create{Domain} = async (
  payload: { name: string; isActive: boolean; /* { 기타 필드 } */ }
): Promise<I{Domain}Response> => {
  const { data } = await axiosInstance.post<I{Domain}Response>(URL_PREFIX, payload);
  return data;
};

export const update{Domain} = async (
  id: number | string,
  payload: { name?: string; isActive?: boolean; /* { 기타 optional 필드 } */ }
): Promise<I{Domain}Response> => {
  const { data } = await axiosInstance.patch<I{Domain}Response>(`${URL_PREFIX}/${id}`, payload);
  return data;
};

export const delete{Domain} = async (id: number | string): Promise<boolean> => {
  await axiosInstance.delete(`${URL_PREFIX}/${id}`);
  return true;
};

// 일괄 삭제 (bulk API 미제공 → 개별 DELETE 반복)
export const deleteBulk{Domain}s = async (ids: (number | string)[]): Promise<void> => {
  await Promise.all(ids.map((id) => delete{Domain}(id)));
};
```

**→ Step 3 완료 후 사용자 확인을 받고 Step 4로 진행한다.**

---

### Step 4. 데이터 훅 (`src/hooks/use{Domain}Data.ts`)

> atomWithQuery/atomWithMutation. 응답 → 도메인 타입 매핑을 이 레벨에서 한 번만 수행.

```typescript
import { atomWithQuery, atomWithMutation } from 'jotai-tanstack-query';
import { queryClient } from '@shared/lib/queryClient';
import { get{Domain}List, create{Domain}, update{Domain}, deleteBulk{Domain}s } from '@/api/{domain}';
import type { {Domain}, Create{Domain}Form, Edit{Domain}Form, I{Domain}Response, I{Domain}ListResponse } from '@/types/{domain}';
import { {domain}ListParamsAtom } from '@/store/{domain}UI';

const {DOMAIN}_KEY = ['{domain}'];

function map{Domain}Response(res: I{Domain}Response): {Domain} {
  return {
    id: res.id ?? '',
    // { 필드 매핑 }
    status: res.isActive ? '활성' : '비활성',
    createdAt: res.createDt ?? '',
  };
}

export const get{Domain}ListAtom = atomWithQuery((get) => {
  const params = get({domain}ListParamsAtom);
  return {
    queryKey: [...{DOMAIN}_KEY, 'list', params],
    queryFn: async () => {
      const res: I{Domain}ListResponse = await get{Domain}List({
        offset: params.offset,
        limit: params.limit,
        searchCategory: params.searchCategory,
        searchKeyword: params.searchKeyword,
      });
      return {
        items: (res.{domain}List ?? []).map(map{Domain}Response),
        total: res.totalCount ?? 0,
      };
    },
    staleTime: 0,
  };
});

export const create{Domain}Atom = atomWithMutation(() => ({
  mutationKey: [...{DOMAIN}_KEY, 'create'],
  mutationFn: async (form: Create{Domain}Form): Promise<{Domain}> => {
    const res = await create{Domain}({ name: form.name, isActive: form.isActive });
    return map{Domain}Response(res);
  },
  onSuccess: () => { void queryClient.invalidateQueries({ queryKey: [...{DOMAIN}_KEY, 'list'] }); },
  onError: (error: unknown) => { console.error('{도메인명} 생성 실패:', error); },
}));

export const update{Domain}Atom = atomWithMutation(() => ({
  mutationKey: [...{DOMAIN}_KEY, 'update'],
  mutationFn: async (form: Edit{Domain}Form): Promise<{Domain}> => {
    const res = await update{Domain}(form.id, { name: form.name, isActive: form.isActive });
    return map{Domain}Response(res);
  },
  onSuccess: () => { void queryClient.invalidateQueries({ queryKey: [...{DOMAIN}_KEY, 'list'] }); },
  onError: (error: unknown) => { console.error('{도메인명} 수정 실패:', error); },
}));

export const deleteBulk{Domain}sAtom = atomWithMutation(() => ({
  mutationKey: [...{DOMAIN}_KEY, 'deleteBulk'],
  mutationFn: async (ids: (number | string)[]): Promise<boolean> => {
    await deleteBulk{Domain}s(ids);
    return true;
  },
  onSuccess: () => { void queryClient.invalidateQueries({ queryKey: [...{DOMAIN}_KEY, 'list'] }); },
  onError: (error: unknown) => { console.error('{도메인명} 삭제 실패:', error); },
}));
```

**→ Step 4 완료 후 사용자 확인을 받고 Step 5로 진행한다.**

---

### Step 5. 핸들러 훅 점검 (`src/hooks/use{Domain}TableHandler.ts`)

> API params 스펙과 기존 UI 상태 파라미터 일치 여부 점검.

- [ ] `searchCategory` 값이 백엔드 쿼리 파라미터명과 일치하는가?
- [ ] `offset = (page - 1) * size`인가?
- [ ] `onSuccess` 후 `invalidateQueries` queryKey가 올바른가?
- [ ] 일괄 삭제 호출부가 `deleteBulk{Domain}sAtom.mutateAsync(selectedIds)` 형태인가?

필요 시 수정할 부분: `{ }`

**→ Step 5 완료 후 사용자 확인을 받고 Step 6(테스트)로 진행한다.**

---

### Step 6. 브라우저 테스트 및 주의사항

> 사전 준비: `localStorage.setItem('accessToken', '<token>')` 후 해당 탭에서 진행.

| #   | 시나리오     | 기대 결과                                      |
| --- | ------------ | ---------------------------------------------- |
| 1   | 목록 진입    | ✅ API 호출 성공, 목록·총 N건 표시             |
| 2   | 검색 후 조회 | ✅ 검색 파라미터 포함 API 호출 (DevTools 확인) |
| 3   | 생성         | ✅ POST 성공, 목록 갱신                        |
| 4   | 수정         | ✅ PATCH 성공, 목록 갱신                       |
| 5   | 단건 삭제    | ✅ DELETE 성공, 목록 갱신                      |
| 6   | 일괄 삭제    | ✅ 건수만큼 DELETE 반복, 목록 갱신             |
| 7   | 401 에러     | ✅ 로그인 리다이렉트 또는 에러 메시지          |
| 8   | 페이지네이션 | ✅ offset 변경 시 올바른 페이지 데이터         |

**주의사항:**

- 게이트웨이 미가동 시 404. 로컬 게이트웨이 먼저 확인.
- bulk API 없는 경우 `Promise.all` 반복 DELETE 사용.
- 공유 atom 초기화 타이밍 주의 (패널 닫힐 때 null 처리).

---

### 최종 확인 체크리스트

| #   | 구분   | 확인 항목                                         | 완료 |
| --- | ------ | ------------------------------------------------- | :--: |
| 1   | 타입   | 기존 화면 타입 수정 없이 유지                     |  ☐   |
| 2   | 타입   | `I{Domain}Response`, `I{Domain}ListResponse` 추가 |  ☐   |
| 3   | API    | `URL_PREFIX` 게이트웨이 라우팅 기준으로 올바름    |  ☐   |
| 4   | API    | axiosInstance + `{ params }` 패턴 사용, mock 제거 완료 |  ☐   |
| 5   | 훅     | 매핑이 `queryFn`/`mutationFn` 안에서만 수행       |  ☐   |
| 6   | 훅     | `onSuccess`에서 `invalidateQueries` 호출          |  ☐   |
| 7   | 훅     | 핸들러 훅 params와 API 스펙 일치                  |  ☐   |
| 8   | 테스트 | 시나리오 1~8 모두 통과                            |  ☐   |
| 9   | 회귀   | 기존 관련 화면 정상 동작 (회귀 없음)              |  ☐   |
