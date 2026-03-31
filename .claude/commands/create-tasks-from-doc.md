# 개발상세정의서 기반 태스크 자동 생성

개발상세정의서(마크다운, 노션 페이지, 엑셀 등)를 분석하여 GitHub Issue와 노션 태스크를 자동 생성합니다.
문서 업데이트 시에도 이 커맨드를 다시 실행하면, 기존 태스크와 비교하여 추가/변경분을 처리합니다.

## 입력

사용자가 제공하는 문서:
- 마크다운 파일 (.md)
- 노션 페이지 URL
- 엑셀/CSV 파일 (.xlsx, .csv)
- 또는 텍스트로 직접 입력

$ARGUMENTS 에 파일 경로, 노션 URL, 또는 "직접입력"이 올 수 있음.

## 실행 단계

### 1단계: 문서 파싱

문서에서 태스크 정보를 추출한다.
각 태스크에서 다음 필드를 식별:

- **id**: TASK-001 형식 (문서 내 ID)
- **title**: 태스크 제목
- **repo**: 대상 레포 (backend-auth, frontend-chat 등)
- **priority**: High / Medium / Low
- **assignee**: 담당자
- **start_date**: 시작일
- **due_date**: 마감일
- **depends_on**: 선행 태스크
- **labels**: 라벨 목록
- **description**: 상세 설명
- **acceptance_criteria**: 완료 조건 (체크리스트)
- **api_spec**: API 스펙 (있으면)
- **notes**: 비고

마크다운이면 ### TASK-XXX 패턴으로 파싱.
엑셀이면 각 행을 하나의 태스크로 파싱.
노션이면 Notion API로 DB 또는 페이지 내용을 조회하여 파싱.

파싱 결과를 사용자에게 보여준다:

```
📋 문서에서 추출한 태스크 (N개):

1. TASK-001: Google OAuth2 로그인 엔드포인트 구현
   repo: backend-auth | priority: High | due: 04/05

2. TASK-002: Google 로그인 프론트엔드 UI
   repo: frontend-chat | priority: High | due: 04/07 | depends: TASK-001

계속 진행할까요?
```

사용자 확인 후 다음 단계로.

### 2단계: 기존 태스크 비교 (업데이트 시)

GitHub Issues를 조회하여 기존에 이 문서에서 생성된 태스크가 있는지 확인한다.
비교 기준: Issue 본문에 포함된 `[TASK-XXX]` 태그.

```bash
gh issue list --repo agent-template-apps/{repo} --state all --json number,title,body --limit 200
```

비교 결과를 3가지로 분류:

**새로 추가된 태스크 (CREATE)**:
문서에는 있지만 GitHub에 없는 것 → 새로 생성

**변경된 태스크 (UPDATE)**:
문서와 GitHub 모두 있지만 내용이 다른 것 (제목, 설명, 우선순위, 일정 등)
→ 변경 내용을 사용자에게 보여주고 업데이트 여부 확인

**삭제된 태스크 (REMOVED)**:
GitHub에는 있지만 문서에서 사라진 것
→ 삭제하지 않고 사용자에게 알려줌 (수동 판단)

```
📊 기존 태스크와 비교 결과:

✅ 새로 추가 (2개):
  - TASK-005: Kakao 로그인 엔드포인트
  - TASK-006: Kakao 로그인 UI

✏️ 변경 감지 (1개):
  - TASK-001: 우선순위 High→Medium, 마감일 04/05→04/08
    → 업데이트할까요? (y/n)

⚠️ 문서에서 제거됨 (1개):
  - TASK-003: 비밀번호 재설정 (#47)
    → Issue를 닫을까요? (y/n)

변경 없음 (2개): TASK-002, TASK-004
```

사용자 확인 후 다음 단계로.

### 3단계: GitHub Issue 생성/업데이트

각 태스크를 해당 레포에 GitHub Issue로 생성한다.

Issue 생성 형식:
```bash
gh issue create \
  --repo "agent-template-apps/{repo}" \
  --title "[TASK-{id}] {title}" \
  --body "{본문}" \
  --label "{labels}" \
  --assignee "{assignee}"
```

Issue 본문 형식:
```markdown
## 설명
{description}

## 완료 조건
{acceptance_criteria 체크리스트}

## API 스펙
{api_spec, 있으면}

## 메타정보
- **문서 ID**: TASK-{id}
- **우선순위**: {priority}
- **시작일**: {start_date}
- **마감일**: {due_date}
- **선행 태스크**: {depends_on}
- **비고**: {notes}
```

업데이트 시:
```bash
gh issue edit {issue_number} \
  --repo "agent-template-apps/{repo}" \
  --title "[TASK-{id}] {title}" \
  --body "{업데이트된 본문}"
```

### 4단계: 노션 태스크 생성/업데이트

GitHub → 노션 동기화 워크플로우가 자동으로 노션에 반영한다.
즉시 반영이 필요하면 Notion API로 직접 생성:

```bash
# 노션 DB에 태스크 추가 (환경변수: NOTION_API_KEY, NOTION_DATABASE_ID)
curl -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer ${NOTION_API_KEY}" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{
    "parent": { "database_id": "'"${NOTION_DATABASE_ID}"'" },
    "properties": {
      "Name": { "title": [{ "text": { "content": "[TASK-{id}] {title}" } }] },
      "Status": { "select": { "name": "To Do" } },
      "Priority": { "select": { "name": "{priority}" } },
      "Repository": { "select": { "name": "{repo}" } },
      "Issue Number": { "number": {issue_number} },
      "Assignee": { "rich_text": [{ "text": { "content": "{assignee}" } }] },
      "Due Date": { "date": { "start": "{start_date}", "end": "{due_date}" } },
      "GitHub URL": { "url": "https://github.com/agent-template-apps/{repo}/issues/{number}" }
    }
  }'
```

### 5단계: 결과 요약

```
✅ 태스크 생성 완료!

GitHub Issues:
  backend-auth:
    #51 [TASK-001] Google OAuth2 로그인 엔드포인트 구현
    #52 [TASK-003] JWT 리프레시 토큰 로직

  frontend-chat:
    #23 [TASK-002] Google 로그인 프론트엔드 UI

노션: 동기화 워크플로우가 5분 이내 반영 예정
  (즉시 반영 완료 시: 노션 DB에 N개 태스크 추가됨)

📌 다음 단계:
  개발자가 /start-task 51 로 작업을 시작할 수 있습니다.
```

## 사용 예시

```
> /create-tasks-from-doc docs/dev-spec-social-login.md
> /create-tasks-from-doc https://notion.so/...
> /create-tasks-from-doc dev-spec.xlsx
```

문서 업데이트 후 재실행:
```
> /create-tasks-from-doc docs/dev-spec-social-login.md
  → 기존 태스크 5개 감지, 2개 추가, 1개 변경, 0개 제거
```
