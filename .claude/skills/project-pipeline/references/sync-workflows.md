# GitHub ↔ 노션 양방향 동기화 설정 가이드

## 사전 준비

### 1. 노션 Integration 생성

1. https://www.notion.so/my-integrations 에서 새 Integration 생성
2. Integration 이름: `GitHub Sync Bot`
3. 권한: Read content, Update content, Insert content, Read comments, Create comments
4. Internal Integration Token을 복사 → GitHub Secrets에 `NOTION_API_KEY`로 등록

### 2. 노션 데이터베이스 생성

칸반보드 뷰로 생성하며, 아래 프로퍼티가 필요합니다:

| 프로퍼티명 | 타입 | 설명 |
|-----------|------|------|
| Name | Title | 태스크 제목 |
| Status | Select | To Do / In Progress / In Review / Done |
| Priority | Select | High / Medium / Low |
| Repository | Select | 레포명 (backend-auth, frontend-chat 등) |
| Issue Number | Number | GitHub Issue 번호 |
| Assignee | Rich Text | 담당자 GitHub ID |
| Due Date | Date | 시작일~마감일 |
| Labels | Multi-select | 라벨 목록 |
| GitHub URL | URL | GitHub Issue 링크 |
| Last Sync | Date | 마지막 동기화 시각 (동기화 봇 전용) |

DB 생성 후:
1. Integration과 DB를 연결 (Share → Integration 선택)
2. DB URL에서 Database ID를 추출 → GitHub Secrets에 `NOTION_DATABASE_ID`로 등록
   - URL 형식: `https://notion.so/{workspace}/{database_id}?v=...`
   - `?v=` 앞의 32자리 hex가 Database ID

### 3. GitHub Secrets 등록

Organization Settings → Secrets and variables → Actions:

| Secret | 값 |
|--------|---|
| NOTION_API_KEY | 노션 Integration Token |
| NOTION_DATABASE_ID | 노션 DB ID |

### 4. 워크플로우 파일 배치

`.github/workflows/` 디렉토리에 아래 두 파일을 배치합니다.
shared-infra의 `.github/workflows/`에 이미 템플릿이 있으니 각 앱 레포로 복사하거나, shared-infra 서브모듈을 통해 공유합니다.

## 워크플로우 구조

### GitHub → 노션 (즉시 동기화)

**트리거**: Issue 생성/수정/닫힘/라벨 변경
**메커니즘**: GitHub Webhook → GitHub Actions → Notion API
**파일**: `sync-github-to-notion.yml`

주요 로직:
1. `sync-bot` 라벨이 있으면 스킵 (무한루프 방지)
2. 노션 DB에서 Issue Number + Repository로 기존 페이지 검색
3. 있으면 업데이트, 없으면 새로 생성
4. 상태 매핑: closed → Done, in-progress 라벨 → In Progress
5. 충돌 감지: 노션 last_edited_time > Last Sync이면 알림
6. Last Sync 타임스탬프 갱신

### 노션 → GitHub (5분 폴링)

**트리거**: cron `*/5 * * * *`
**메커니즘**: GitHub Actions → Notion API 쿼리 → GitHub API
**파일**: `sync-notion-to-github.yml`

주요 로직:
1. 최근 6분간 수정된 노션 페이지 조회
2. 봇 변경 감지: edit_time ≈ Last Sync (10초 이내) → 스킵
3. Issue Number가 있으면 → 기존 Issue 업데이트
4. Issue Number가 없으면 → 새 Issue 생성 후 노션에 Issue Number 기록
5. 충돌 감지: GitHub updated_at > Last Sync이면 변경 거부 + 노션 코멘트
6. `sync-bot` 라벨 추가 (GitHub → 노션 워크플로우에서 스킵하도록)
7. Last Sync 타임스탬프 갱신

## 충돌 처리

양방향 동기화에서 충돌은 다음과 같이 처리합니다:

### GitHub에서 수정 + 노션에서도 수정 (동시)

1. GitHub → 노션 동기화가 먼저 실행 (즉시 반영)
2. GitHub 변경사항으로 노션을 덮어쓰고, 충돌 알림 코멘트 추가
3. 노션 → GitHub 동기화 실행 시, 충돌 감지 → 변경 거부 + 노션 코멘트

### 충돌 해결 플로우

1. 사용자가 노션/GitHub에서 충돌 알림 확인
2. 최종 값을 결정하여 한쪽에서 다시 수정
3. 다음 동기화 주기에 정상 반영

### 감수해야 할 불편함

| 항목 | 내용 | 대책 |
|------|------|------|
| 동기화 지연 | 노션→GitHub는 최대 5분 딜레이 | 급할 때 수동 워크플로우 실행 |
| 충돌 알림 | 동시 수정 시 노션 코멘트로 알림 | 같은 태스크를 동시에 수정하지 않기 |
| API 속도 제한 | 노션 API: 3req/sec | 태스크 200개 이하면 문제 없음 |
| GitHub Actions 비용 | 5분 폴링 = 월 8,640분 | Free tier로 충분 (2,000분/월은 부족, Team 3,000분) |
