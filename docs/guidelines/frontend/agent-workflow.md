# 에이전트 팀 운영 가이드

기능 구현 시 아래 3단계 에이전트 팀으로 작업합니다.
**Foundation → Publishing → UI** 순서를 반드시 지킵니다.

> 각 팀원은 @.claude/rules/coding-standards.md 와 @.claude/rules/state-management.md 의 상세 규칙을 준수합니다.

## 작업 대상 앱 확인

작업 시작 전 **어떤 앱(admin / chat / shared)을 수정하는지** 먼저 확인한다.
- `admin/src/` — 관리자 기능
- `chat/src/` — 채팅 기능
- `shared/` — 양쪽 공통 코드 (수정 시 admin, chat 양쪽 호환성 확인 필수)

---

## PM (리드) 역할

- 작업 대상 앱 확인 후 Foundation / Publishing / UI 세 팀원으로 분해
- 팀원 실행 순서 통제 (Foundation → Publishing → UI 순서 엄수)
- 각 팀원 결과물 검토 및 수정 지시
- `routes/AppRoutes.tsx` 등 공통 파일은 PM이 직접 작성
- 이전 단계 검토를 통과하기 전에 다음 팀원을 시작하지 않음

### 작업 분해 형식

```
[대상 앱: admin | chat]

[Foundation 작업]
- {app}/src/types/{domain}.ts 정의 (도메인 모델 → Response/Request 타입)
- {app}/src/api/{domain}.ts API 함수 작성
- {app}/src/data/{파일}.ts Mock 데이터 작성
- {app}/src/store/{domain}UI.ts 순수 클라이언트 상태 atom 정의
- {app}/src/hooks/use{Domain}Data.ts API atom 정의 (atomWithQuery/atomWithMutation)
- {app}/src/hooks/use{Domain}Handler.ts 핸들러 훅 작성 (필요 시)

[Publishing 작업]
- {app}/src/components/ui/{컴포넌트}.tsx 마크업·스타일
- {app}/src/components/features/{도메인}/{컴포넌트}.tsx 마크업·스타일
- {app}/src/components/layout/{컴포넌트}.tsx 마크업·스타일
- {app}/src/pages/{페이지}.tsx (독립 전체화면만)

[UI 작업]
- Publishing 결과물에 훅 연결
- 하드코딩 더미 데이터 → hooks/ import로 교체 (useAtomValue/useSetAtom)
- 빈 이벤트 핸들러 → 실제 로직 연결
- 하드코딩 문자열 → t() 함수로 교체 + locale 파일에 키 추가
```

---

## Foundation 팀원

타입·상태·로직·데이터의 기반을 구축합니다.

### 담당 디렉토리

```
{app}/src/types/  {app}/src/store/  {app}/src/hooks/  {app}/src/api/  {app}/src/data/
shared/ (공통 코드 추가 시)
```

### 절대 규칙

- `components/`, `pages/`, `routes/` 파일은 직접 구현하지 않음. 단, 타입 변경으로 인한 import/타입 오류 수정은 허용
- 모든 파일을 named export로 작성
- 작업 완료 전 반드시 import 경로 오류가 없는지 확인

### 작업 순서

1. **types/** — 다른 모든 파일이 의존. 타입 정의 규칙은 coding-standards "타입 정의 규칙" 참조
2. **api/** — API 함수 정의. 호출 패턴은 coding-standards "API 호출 패턴" 참조
3. **data/** — Mock 데이터 작성 (camelCase 타입 기준, 현실적 값)
4. **store/** — 순수 클라이언트 상태만. 공유 상태가 없으면 생략 가능. 규칙은 state-management "클라이언트 상태 — Jotai" 참조
5. **hooks/Data** — `atomWithQuery`/`atomWithMutation` 정의. 규칙은 state-management "API 상태 — jotai-tanstack-query" 참조
6. **hooks/Handler** — 복합/공유 로직 훅. 불필요하면 생략 가능. 분리 기준은 coding-standards "hooks/ 파일 분류" 참조

### 완료 체크리스트

- [ ] 모든 interface 필드가 camelCase, `any` 없음
- [ ] 도메인 모델 우선 정의, Response는 추가 필드 있을 때만 정의
- [ ] API 함수가 `@shared/lib/axios`의 `axiosInstance` 사용, body/params 구분 명확, 변환 로직 없음
- [ ] store에 `atomWithQuery`/`atomWithMutation` 없음 (순수 클라이언트 상태만)
- [ ] hooks/Data에 `atomWithQuery`/`atomWithMutation` 정의, CUD `onSuccess`에서 query invalidate
- [ ] import 경로가 `@/` 또는 `@shared/`, 모든 파일이 named export
- [ ] `components/`, `pages/`, `routes/`를 수정하지 않았는가

---

## Publishing 팀원

Foundation 완료 후 실행됩니다. 디자인을 마크업·스타일로 구현합니다. 로직 연결은 하지 않습니다.

> 컴포넌트·스타일링 상세 규칙은 coding-standards "컴포넌트 규칙" / "스타일링 규칙" 참조

### 디자인 입력 형태

| 형태 | 접근 방식 |
|------|-----------|
| **Figma 링크** | Figma MCP로 확인. 크기·간격·색상 정확 반영. Auto Layout → Tailwind Flex/Grid |
| **스크린샷 이미지** | 레이아웃 유사 구현. 수치 근사. 불확실한 부분 PM에게 보고 |
| **텍스트 설명** | 기존 UI 컴포넌트 기본값 따름. 임의 결정 부분 PM에게 보고 |

### 담당 디렉토리

```
{app}/src/components/  {app}/src/pages/
```

### 절대 규칙

- `hooks/`, `store/`, `api/` import를 절대 하지 않음
- 이벤트 핸들러는 빈 함수(`() => {}`)로만 작성 — 실제 로직 금지
- 문자열은 하드코딩으로 작성 — `t()` 적용 금지 (UI 팀원이 교체)
- 더미 데이터는 props로 직접 넘기거나 컴포넌트 안에 하드코딩
- `types/`에서 정의된 interface는 Props 타입으로 import해서 사용
- `routes/`는 수정하지 않음

### 완료 체크리스트

- [ ] `hooks/`, `store/`, `api/` import가 없는가
- [ ] 모든 이벤트 핸들러가 빈 함수(`() => {}`)인가
- [ ] 문자열이 하드코딩되어 있는가 (`t()` 미적용 상태)
- [ ] 시맨틱 Tailwind 클래스 사용, 인라인 `style` 없음
- [ ] hover·focus 상태가 구현되어 있는가
- [ ] Props가 `{컴포넌트명}Props` interface로 파일 상단에 선언, `export default` 1개
- [ ] `routes/`를 수정하지 않았는가

---

## UI 팀원

Publishing 완료 후 실행됩니다. 마크업에 로직을 연결합니다. 마크업·스타일 변경은 최소화합니다.

> atom 사용 패턴(`useAtomValue`/`useSetAtom`, 이름 재정의, 금지 패턴)은 state-management "컴포넌트에서 atom 사용" 참조

### 담당 범위

Publishing이 생성한 `components/`, `pages/` 파일을 수정합니다.

### 절대 규칙

- `types/`, `store/`, `hooks/`, `api/`, `data/` 파일은 새로 생성하지 않음
- Foundation에서 만들어진 훅·atom·타입만 import해서 사용
- 로직 연결 중 새로운 공유 상태 atom, 핸들러 훅 등이 필요하면 **Foundation 팀원에게 작성을 요청**
- 마크업·스타일·레이아웃 구조는 변경하지 않음 — 로직만 붙임
- 복합/공유 비즈니스 로직을 컴포넌트 안에 직접 작성하지 않음 (단순 UI 상태·포맷팅·1회 API 호출은 내부 OK)
- `routes/`는 수정하지 않음 — PM 담당

### 작업 내용

1. **하드코딩 더미 데이터 → hooks/ import로 교체** — Query는 `useAtomValue`, Mutation은 `useSetAtom`
2. **빈 이벤트 핸들러(`() => {}`) → 실제 로직 연결**
3. **하드코딩 문자열 → `t()` 함수로 교체** + locale 파일에 키 추가
4. **전역 상태 연결** — store atom은 `useAtomValue`/`useSetAtom`으로 사용

### 완료 체크리스트

- [ ] 하드코딩 더미 데이터가 모두 hooks/ import로 교체되었는가
- [ ] Query는 `useAtomValue` + 이름 재정의, Mutation은 `useSetAtom` 사용하는가
- [ ] 빈 이벤트 핸들러가 모두 실제 로직으로 연결되었는가
- [ ] 하드코딩 문자열이 모두 `t()` 함수로 교체되었는가
- [ ] 복합/공유 로직이 컴포넌트 밖(훅)에 있는가
- [ ] `any` 타입 없음, `@/` 또는 `@shared/` 절대 경로 사용
- [ ] `types/`, `store/`, `hooks/`, `api/`, `data/`를 직접 생성하지 않았는가 (필요 시 Foundation에 요청)
- [ ] 마크업·스타일 구조가 Publishing 결과와 동일하게 유지되었는가
- [ ] `routes/`를 수정하지 않았는가

---

## PM 검토 체크리스트

### Foundation 검토

- [ ] types/ — 도메인 모델 우선 정의, Response/Request 네이밍 규칙 준수
- [ ] api/ — `@shared/lib/axios`의 `axiosInstance` 사용, body/params 구분, 변환 로직 없음
- [ ] store/ — 순수 클라이언트 상태만 (`atomWithQuery`/`atomWithMutation` 없음)
- [ ] hooks/Data — API atom 정의, CUD `onSuccess`에서 query invalidate
- [ ] hooks/Handler — 복합/공유 로직이 훅으로 분리
- [ ] import 경로 `@/` 또는 `@shared/`, named export, `any` 없음

### Publishing 검토

- [ ] 디자인과 레이아웃·스타일이 일치하는가
- [ ] hooks/, store/, api/ import가 없는가
- [ ] 이벤트 핸들러가 빈 함수로만 작성되어 있는가
- [ ] 컴포넌트 위치·네이밍·스타일링이 coding-standards 규칙에 부합하는가

### UI 검토

- [ ] 하드코딩 모두 제거, `t()` 적용 완료
- [ ] atom 사용 패턴이 state-management 규칙에 부합하는가
- [ ] 비즈니스 로직이 컴포넌트 밖(훅)에 있는가
- [ ] `any` 없음, 마크업 구조 변경 없음
