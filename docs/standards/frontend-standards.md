# 프로젝트 개요

프론트엔드 멀티앱 레포. React + TypeScript + Vite + PNPM.

## 워크스페이스 구조

```
frontend/
├── admin/          # 관리자 대시보드 (port 3001)
├── chat/           # 채팅 UI (port 3000)
└── shared/         # 양쪽 앱 공통 코드 (인증, HTTP, 유틸)
```

- 각 앱은 독립 `package.json`, `vite.config.ts`, `tsconfig.json` 보유
- 패키지 설치: 각 앱 디렉토리에서 `pnpm i {패키지명}`
- 개발 서버: 각 앱 디렉토리에서 `pnpm dev`

## Import alias

| alias | 해석 | 용도 |
|-------|------|------|
| `@/` | 해당 앱의 `./src/` | 앱 내부 코드 |
| `@shared/` | `../shared/` | 공통 코드 |

## 기술 스택 요약

Jotai · jotai-tanstack-query · TanStack Query · Axios · Tailwind CSS · lucide-react · TanStack Table · react-i18next
- chat 추가: react-markdown · react-syntax-highlighter · jotai-family

## 절대 금지

- `any` 타입 금지
- 하드코딩 문자열 금지 → `t()` 사용
- 상대경로 import 금지 → `@/` 또는 `@shared/` 절대경로 사용
- snake_case 필드 직접 사용 금지 → Axios interceptor에서 camelCase 변환
- `main`, `develop` 브랜치 직접 커밋 금지 → 반드시 feature 브랜치에서 작업

## 핵심 규칙

- 함수형 컴포넌트 + 화살표 함수만 사용
- Props와 데이터 모델은 `interface` 선호
- 네이밍: 컴포넌트·파일명 `PascalCase`, 훅·유틸·변수명 `camelCase`
- 컴포넌트는 UI 렌더링만, 비즈니스 로직은 `hooks/`로 분리
- 전역 상태는 `store/`에 Jotai atom, 단일 컴포넌트 전용은 `useState`
- 공통 코드(인증, HTTP 클라이언트, 유틸)는 `shared/`에 배치

## 백엔드 연동 정보

- 백엔드 레포: `agent-template-apps` organization 내 `backend-*` 레포들
- 로컬 프록시: `/api/v1` → `http://0.0.0.0:8000` (Gateway)
- 아키텍처: `app/api/routes/` (라우터) · `app/service/model/` (Pydantic 모델) · `app/service/` (비즈니스 로직)
- API prefix: `/api/v1`

## 참조 문서

- 코딩 표준 / 디렉토리 구조: `docs/guidelines/frontend/coding-standards.md`
- 상태 관리 패턴: `docs/guidelines/frontend/state-management.md`
- Git 컨벤션: `docs/guidelines/frontend/git-convention.md`
- API 연동 절차: `docs/guidelines/frontend/api-connect.md`
- 에이전트 팀 운영: `docs/guidelines/frontend/agent-workflow.md`
