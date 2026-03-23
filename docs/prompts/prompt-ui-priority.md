# [prompt] 화면(UI) 우선 개발 지시 프롬프트

> **사용 시점**: API 연동은 추후로 미루고 Mock 데이터로 화면만 먼저 구현할 때
>
> **AI에게 반드시 함께 첨부할 문서**:
> - `docs/prompts/ref-new-page-template.md` — 구현 계획서 템플릿 (Step 3, 5를 Mock 버전으로 대체)
> - `docs/guidelines/frontend-code-patterns.md` — 아키텍처 패턴 레퍼런스
> - `.cursor/rules/frontend-app-structure.mdc` — 프로젝트 규칙

---

## 요청 문구 (복사 후 `{ }` 채워서 사용)

```
당신은 이 레포지토리(agent-template)의 구조를 이해하는 시니어 풀스택 개발자입니다.
목표: `{도메인명}` 화면을 Mock 데이터 기반으로 구현한다.
API 연동은 추후 진행하므로, ref-new-page-template의 Step 3(API 레이어)와 Step 5(Data 훅)를
각 Step 하단의 **Mock 대체** 안내로 대체하여 계획서를 작성한다.

## 반드시 준수할 규칙

- `.cursor/rules/frontend-app-structure.mdc` 전면 준수
- Step 3 대체: `src/api/` 파일 없이 `src/data/mock{Domain}.ts` 생성
- Step 5 대체: `atomWithQuery` 없이 plain `atom`으로 mock 데이터 제공
  - `get{Domain}ListAtom`은 `{domain}ListParamsAtom`에서 파생된 computed atom으로 구현
  - 클라이언트 사이드 필터·페이지네이션 처리
  - API 전환 시 이 파일(`use{Domain}Data.ts`)만 `atomWithQuery`/`atomWithMutation`으로 교체
- Store·핸들러 훅·컴포넌트 구조는 API 버전과 동일하게 유지
- **각 Step 완료 후 반드시 사용자에게 결과를 보고하고 확인을 받은 뒤 다음 Step을 진행한다.**

## 참고 기준

- 기존 페이지/컴포넌트: `{참고할 기존 도메인 ex. Users, Organizations}`
```
