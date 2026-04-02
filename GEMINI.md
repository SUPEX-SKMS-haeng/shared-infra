# Agent Template Apps - 공통 개발 규칙

## 프로젝트 구조

- 멀티 레포: `agent-template-apps` GitHub Organization
- 백엔드: backend-auth, backend-base, backend-chat, backend-llm-gateway, backend-mcp
- 프론트엔드: frontend (chat + admin 통합)
- 공통 인프라: shared-infra (이 레포)
- 각 앱은 `infra/` 서브모듈로 shared-infra를 참조

## Git 워크플로우

- 브랜치 전략: `main` (운영), `develop` (개발)
- 기능 브랜치: `feat/{앱약어}/{이슈번호}-{설명}` (예: `feat/be-auth/12-add-oauth`)
- 버그 수정: `fix/{앱약어}/{이슈번호}-{설명}`
- 커밋 메시지: `type(scope): description` (Conventional Commits)
  - type: feat, fix, refactor, test, docs, chore
  - scope: 앱 약어 (auth, chat, admin 등)
- PR 생성 시 반드시 관련 Issue 번호 연결 (`Closes #123`)
- PR은 최소 1명 리뷰 후 머지

## 전체 서비스 공통 규약

### API 응답 형식

- 성공: `{"success": true, "data": any}`
- 실패: `{"success": false, "error": {"code": int, "name": str, "message": str}}`
- IMPORTANT: 모든 API는 위 형식을 따라야 함

### 에러 코드 체계

- 1XXXX: 클라이언트 오류 (4XX) — X0: 공통, X1: 인증, X2: 사용자, X3: 리소스, X4: 파일, X5: AI/모델
- 9XXXX: 서버 오류 (5XX) — 90: 일반, 94: 파일, 95: AI/모델, 98: 외부서비스, 99: DB
- 새 에러 코드 추가 시 번호 체계를 따르고 충돌 방지

## PR 자동 리뷰

- 모든 레포에 `gemini-review.yml` 설정됨
- PR 생성/업데이트 시 Gemini가 자동으로 코드 리뷰 수행
- 리뷰 기준: 기능 충족, 아키텍처, 에러 처리, 보안, 코드 품질, 테스트
- PL은 Gemini 리뷰 결과를 확인한 후 최종 Approve/머지 판단

## 공통 주의사항

- IMPORTANT: `.env`, 시크릿, API 키는 절대 커밋하지 않음
- IMPORTANT: 기존 코드 패턴을 먼저 확인하고 따를 것 — 새 패턴 도입 전 팀 합의
- IMPORTANT: 새 의존성 추가 전 기존 라이브러리로 해결 가능한지 확인
- 한국어 주석/문서 작성
