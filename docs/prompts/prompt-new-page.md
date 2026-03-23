# [prompt] 새 관리 페이지 구현 요청 프롬프트

> **사용 시점**: 새 페이지를 처음부터 만들 때 (화면 + API 연동 동시)
> **사용 방법**: 아래 블록 내용을 복사하고 `{ }` 부분을 채워 AI에게 제공한다.
>
> **AI에게 반드시 함께 첨부할 문서**:
> - `docs/guidelines/frontend-code-patterns.md` — 아키텍처 패턴 레퍼런스
> - `docs/prompts/ref-new-page-template.md` — 구현 계획서 템플릿
> - `.cursor/rules/frontend-app-structure.mdc` — 프로젝트 규칙

---

```markdown
당신은 이 레포지토리(agent-template)의 구조를 이해하는 시니어 풀스택 개발자입니다.
목표: `{도메인명}` 관리 페이지를 구현한다. 백엔드 수정 없음. 프론트엔드 연동만 진행한다.

## 반드시 준수할 규칙

- `.cursor/rules/frontend-app-structure.mdc` 전면 준수
- Mock 데이터 사용 금지. 실제 API만 호출.
- `{Domain}s.tsx` (컨테이너)는 UI atom을 직접 구독하지 않음.
  → `use{Domain}TableHandler` 훅에서 일괄 구독 후 값·핸들러 묶음 반환.
- 컴포넌트 위치: `src/components/features/{domain}/`
- 테스트: 브라우저에서 페이지를 띄운 상태로 진행.
- **각 Step 완료 후 반드시 사용자에게 결과를 보고하고 확인을 받은 뒤 다음 Step을 진행한다.**

---

## 1. UI 요구사항

- 레이아웃: `{기준 페이지 ex. Organizations, Users}` 페이지와 유사.
  상단 타이틀, 검색/필터 영역, 액션바, DataTable, 페이지네이션, 일괄 삭제(휴지통 아이콘).
- 상세 화면: 테이블 행 클릭 → 모달. 라벨-값 형태 + 수정/삭제 버튼.
- 등록/수정 모달: FormModal 하나에 `mode='create'|'edit'` 구분.
- 테이블 컬럼: {컬럼 목록 ex. 체크박스, Provider, Model, Endpoint, 상태, 생성일시}
- 특수 UI 처리: {ex. Access Key 마스킹, 상태 뱃지 등. 없으면 삭제}

---

## 2. 백엔드 API 명세 (수정하지 않음)

라우터 파일: `{backends/xxx/app/api/routes/xxx.py}`
게이트웨이 라우팅: `URL_PREFIX = '{/llm-gateway/deployments 등}'`

| 메서드 | 경로             | 역할      | 주요 파라미터                      |
| ------ | ---------------- | --------- | ---------------------------------- |
| GET    | `/{prefix}`      | 목록 조회 | `offset, limit, {검색 파라미터}`   |
| POST   | `/{prefix}`      | 생성      | body: `{snake_case 필드 목록}`     |
| GET    | `/{prefix}/{id}` | 상세 조회 | path: id                           |
| PATCH  | `/{prefix}/{id}` | 수정      | body: `{필드 목록, 모두 optional}` |
| DELETE | `/{prefix}/{id}` | 삭제      | path: id                           |

목록 응답: `{ {domain}_list: [...], total_count, next_offset }`
단건 응답 필드: `id, {snake_case 필드 목록}, is_active, create_dt, update_dt`

---

## 3. 구현 계획서 작성 요청

> 함께 제공된 `ref-new-page-template.md` 구현 계획서 템플릿의 각 Step 중 `{ }` 빈칸을 채워 완성된 계획서를 작성할 것.
> 작성 완료 후 사용자 확인을 받고 코드 구현을 시작한다.
```
