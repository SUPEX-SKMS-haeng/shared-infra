# [prompt] 기존 화면 API 연동 요청 프롬프트

> **사용 시점**: 화면(Mock)이 이미 구현된 상태에서 API 연동만 진행할 때
> **사용 방법**: 아래 블록 내용을 복사하고 `{ }` 부분을 채워 AI에게 제공한다.
>
> **AI에게 반드시 함께 첨부할 문서**:
> - `docs/guidelines/frontend-code-patterns.md` — 아키텍처 패턴 레퍼런스
> - `docs/prompts/ref-api-integration-template.md` — 구현 계획서 템플릿
> - `.cursor/rules/frontend-app-structure.mdc` — 프로젝트 규칙

---

```markdown
당신은 이 레포지토리(agent-template)의 구조를 이해하는 시니어 풀스택 개발자입니다.
목표: `{백엔드 서비스}`의 `{도메인}` API를 `{연동 대상 컴포넌트/페이지}`와 연동한다.
백엔드 수정 없음. 프론트엔드 API 연동만 진행한다.

## 반드시 준수할 규칙

- `.cursor/rules/frontend-app-structure.mdc` 전면 준수
- DTO 정책: API 응답 인터페이스(`IXxxResponse`)와 화면 타입(`Xxx`) 분리.
  변환은 hook/atom 내부에서 한 번만 수행.
- axiosInstance: `@shared/lib/axios` 사용, 쿼리 스트링: `qs.stringify`.
- 테스트: 브라우저에서 진행. (curl/Postman은 보조 수단)
- **각 Step 완료 후 반드시 사용자에게 결과를 보고하고 확인을 받은 뒤 다음 Step을 진행한다.**

---

## 1. 현재 상황 파악

### 백엔드 (참고용, 수정하지 않음)

- 라우터 파일: `{backends/xxx/app/api/routes/xxx.py}`
- 게이트웨이 라우팅 규칙: `{^/api/v1/auth/(.*) → /api/v1/$1 형식}`
- → `URL_PREFIX = '{/auth/organization 등}'`

엔드포인트 목록 (파악 후 2단계 양식 표에 기입할 것):
| 용도 | 메서드 | URL | 요청 | 응답 → 프론트 타입 |
|------|--------|-----|------|-------------------|
| { } | { } | { } | { } | { } |

### 프론트엔드

- 기존 타입 파일: `{src/types/xxx.ts}`
- 연동 대상 컴포넌트: `{src/components/features/xxx/}`
- 현재 Mock 방식: `{mockData 함수명 또는 파일경로}`

---

## 2. DTO 및 타입 정책

- 기존 화면용 타입(`{Domain}`, `Create{Domain}Form` 등)은 **그대로 유지**.
- API 응답과 1:1 대응하는 인터페이스(`I{Domain}Response` 등)만 **추가**.
- 추가된 인터페이스는 `api/` 또는 `hooks/`에서만 import해 매핑에만 사용.
- TanStack Query(`atomWithQuery`/`atomWithMutation`) 활용.
  API 응답 → 화면 타입 변환은 **훅/atom 레벨에서 한 번만** 수행.

---

## 3. 구현 계획서 작성 요청

> 함께 제공된 `ref-api-integration-template.md` 구현 계획서 템플릿의 각 Step 중 `{ }` 빈칸을 채워 완성된 계획서를 작성할 것.
> 작성 완료 후 사용자 확인을 받고 코드 구현을 시작한다.
```
