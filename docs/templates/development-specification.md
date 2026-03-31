# 개발상세정의서

> 이 문서는 요구사항을 개발 태스크로 분해한 결과입니다.
> `/create-tasks-from-doc`에 이 문서를 전달하면 GitHub Issue + 노션 태스크가 자동 생성됩니다.
> 문서 업데이트 후 다시 전달하면, 기존 태스크와 비교하여 추가/변경분을 처리합니다.

## 프로젝트 정보

| 항목 | 내용 |
|------|------|
| 프로젝트명 | |
| 요구사항정의서 | (링크 또는 문서명) |
| 작성자 | |
| 작성일 | |
| 전체 일정 | (예: 2026-04-01 ~ 2026-04-30) |

---

## 태스크 목록

<!--
  각 태스크는 아래 형식을 따릅니다.
  Claude Code가 이 형식을 파싱하여 GitHub Issue와 노션 태스크를 생성합니다.

  필수 필드: id, title, repo, description
  선택 필드: priority, assignee, start_date, due_date, depends_on, acceptance_criteria, api_spec
-->

### TASK-001: Google OAuth2 로그인 엔드포인트 구현
- **repo**: backend-auth
- **priority**: High
- **assignee**: (담당자)
- **start_date**: 2026-04-01
- **due_date**: 2026-04-05
- **depends_on**: (없음 또는 TASK-XXX)
- **labels**: feature, auth
- **description**:
  사용자가 Google 계정으로 로그인할 수 있도록 OAuth2 인증 엔드포인트를 추가한다.
- **acceptance_criteria**:
  - [ ] POST /api/v1/auth/google 엔드포인트 동작
  - [ ] Google OAuth2 토큰 검증
  - [ ] 신규 사용자 자동 회원가입
  - [ ] JWT 액세스/리프레시 토큰 발급
- **api_spec**:
  - `POST /api/v1/auth/google` — body: `{ "credential": "google_id_token" }` → response: `{ "access_token", "refresh_token" }`
- **notes**:
  Google Cloud Console에서 OAuth 2.0 클라이언트 ID 필요

### TASK-002: Google 로그인 프론트엔드 UI
- **repo**: frontend-chat
- **priority**: High
- **assignee**:
- **start_date**: 2026-04-03
- **due_date**: 2026-04-07
- **depends_on**: TASK-001
- **labels**: feature, auth, ui
- **description**:
  로그인 페이지에 "Google로 로그인" 버튼을 추가하고, OAuth2 플로우를 연동한다.
- **acceptance_criteria**:
  - [ ] Google 로그인 버튼 UI
  - [ ] Google OAuth2 리다이렉트 플로우
  - [ ] 로그인 성공 시 토큰 저장 및 메인 페이지 이동
  - [ ] 에러 처리 (인증 실패, 네트워크 오류)
- **notes**:
  @react-oauth/google 라이브러리 사용 권장

### TASK-003: (태스크 제목)
- **repo**:
- **priority**:
- **assignee**:
- **start_date**:
- **due_date**:
- **depends_on**:
- **labels**:
- **description**:
- **acceptance_criteria**:
  - [ ]
- **api_spec**:
- **notes**:

<!-- TASK-번호를 늘려가며 추가 -->

---

## 일정 요약

<!-- @task-planner가 자동 생성하거나, 직접 작성 -->

| 주차 | 기간 | 주요 태스크 |
|------|------|------------|
| 1주차 | 04/01 ~ 04/05 | TASK-001 (백엔드 OAuth), TASK-002 시작 |
| 2주차 | 04/06 ~ 04/12 | TASK-002 완료, TASK-003 |

## 리스크 및 이슈

<!-- 일정 지연 가능성, 기술적 리스크, 외부 의존성 등 -->

- (예: Google API 승인 절차에 2~3일 소요 가능)
