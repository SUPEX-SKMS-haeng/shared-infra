# docs/ 가이드

이 폴더는 프론트엔드 개발에 필요한 **패턴 레퍼런스**와 **AI 작업 요청 프롬프트 템플릿**을 담고 있습니다.

---

## 문서 구조

```
docs/
├── README.md                          ← 이 파일 (인덱스 & 사용 가이드)
├── guidelines/
│   └── frontend-code-patterns.md     ← 아키텍처 패턴 레퍼런스
└── prompts/
    ├── prompt-new-page.md             ← [프롬프트] 새 페이지 (화면 + API)
    ├── ref-new-page-template.md       ← [템플릿] 새 페이지 구현 계획서
    ├── prompt-api-integration.md      ← [프롬프트] 기존 화면에 API 연동
    ├── ref-api-integration-template.md← [템플릿] API 연동 구현 계획서
    └── prompt-ui-priority.md          ← [프롬프트] UI(Mock)만 먼저 구현
```

---

## 1. 패턴 레퍼런스 (`guidelines/frontend-code-patterns.md`)

새로운 화면이나 기능을 만들기 전에 한 번 읽어야 할 문서입니다.

- 레이어 구조(`types / api / store / hooks / components`)
- DTO/타입 분리 정책 (뷰 모델 vs API 응답 타입)
- `use*Data.ts` — 서버 상태 + DTO 매핑 패턴
- `use*TableHandler.ts` — 이벤트 핸들러 훅 패턴
- 컨테이너 컴포넌트 패턴 (데이터·UI 상태 구독 + 핸들러 훅 사용)
- 공통 UI 컴포넌트(`DataTable`, `SearchBar`, `Pagination`) 사용 방법

---

## 2. 새 페이지 구현 시 사용 흐름

### A. 새 페이지 (화면 + API 동시)

```
1. frontend-code-patterns.md 로 패턴 이해
2. prompt-new-page.md (아래 첨부 목록 포함) 를 AI에게 전달
3. AI가 ref-new-page-template.md 를 채워 계획서 제시
4. 계획 승인 → 코드 구현
```

**AI에게 첨부할 파일**:

| 필수 | 파일 |
|---|---|
| ✅ | `docs/prompts/prompt-new-page.md` |
| ✅ | `docs/prompts/ref-new-page-template.md` |
| ✅ | `docs/guidelines/frontend-code-patterns.md` |
| ✅ | `.cursor/rules/frontend-app-structure.mdc` |

---

### B. 기존 Mock 화면에 API만 연동

```
1. frontend-code-patterns.md 의 DTO/매핑 패턴 확인
2. prompt-api-integration.md (아래 첨부 목록 포함) 를 AI에게 전달
3. AI가 ref-api-integration-template.md 를 채워 계획서 제시
4. 계획 승인 → 코드 구현
```

**AI에게 첨부할 파일**:

| 필수 | 파일 |
|---|---|
| ✅ | `docs/prompts/prompt-api-integration.md` |
| ✅ | `docs/prompts/ref-api-integration-template.md` |
| ✅ | `docs/guidelines/frontend-code-patterns.md` |
| ✅ | `.cursor/rules/frontend-app-structure.mdc` |

---

### C. UI(Mock)만 먼저 구현

```
1. frontend-code-patterns.md 로 패턴 이해
2. prompt-ui-priority.md + ref-new-page-template.md 를 AI에게 전달
   → AI가 ref-new-page-template의 Step 3, 5를 Mock 버전으로 대체해 계획서 작성
3. 계획 승인 → 코드 구현
4. API 전환 시: use*Data.ts 파일만 atomWithQuery 버전으로 교체, data/mock*.ts 삭제
```

**AI에게 첨부할 파일**:

| 필수 | 파일 |
|---|---|
| ✅ | `docs/prompts/prompt-ui-priority.md` |
| ✅ | `docs/prompts/ref-new-page-template.md` |
| ✅ | `docs/guidelines/frontend-code-patterns.md` |
| ✅ | `.cursor/rules/frontend-app-structure.mdc` |

---

## 3. 공통 규칙

모든 프론트엔드 관련 작업에서 `.cursor/rules/frontend-app-structure.mdc`는 **항상 함께 첨부**해야 합니다.

각 프롬프트 내부의 **"반드시 준수할 규칙"** 항목도 AI에게 명시적으로 전달되어야 합니다.
