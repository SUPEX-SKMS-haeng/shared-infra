---
name: project-pipeline
description: |
  프로젝트 관리 문서 파이프라인 자동화 스킬. 요구사항정의서(엑셀/마크다운)를 입력하면 업무기능분해도 → 상세기능설계서 → 태스크(GitHub Issue + 노션 칸반보드) → 일정표까지 자동 생성합니다.
  이 스킬은 다음 상황에서 반드시 사용하세요: 프로젝트 초기 세팅, 요구사항 문서 변환, WBS 생성, 상세기능설계서 작성, 태스크 자동 생성, 일정 산정, 개발 문서 파이프라인 구축, 프로젝트 계획 수립, 스프린트 계획 등. "요구사항 정리해줘", "태스크 만들어줘", "일정 짜줘", "WBS 만들어줘", "설계서 써줘" 같은 요청에도 이 스킬을 사용하세요.
---

# 프로젝트 관리 문서 파이프라인

요구사항정의서를 입력받아 4단계 문서 파이프라인을 실행합니다.

```
요구사항정의서 (고객에게 받음, 엑셀/md)
        ↓ Step 1: 업무 관점으로 재구성
업무기능분해도 (업무기능 트리, 엑셀)
        ↓ Step 2: 개발 스펙으로 변환
상세기능설계서 (프로세스별 구현 스펙, 엑셀)
        ↓ Step 3: 태스크 생성 + 일정 산정
태스크 (GitHub Issue + 노션 칸반보드)
일정표 (스프린트 계획, 엑셀/노션 타임라인)
```

## 시작하기 전에

사용자에게 다음을 확인하세요:

1. **요구사항정의서 파일 경로** — 엑셀(.xlsx), 마크다운(.md), CSV 모두 가능
2. **프로젝트 기본 정보** — 프로젝트명, 시작일, 목표 완료일
3. **어디까지 실행할지** — 전체 파이프라인 vs 특정 단계만
4. **GitHub Organization/레포 구조** — 태스크 생성 시 필요
5. **노션 연동 여부** — 노션 API 키와 DB ID가 있는지

전체 파이프라인을 한번에 실행할 수도 있고, 각 단계를 개별로 실행할 수도 있습니다. 각 단계가 끝날 때마다 사용자에게 결과를 보여주고 확인을 받으세요 — 자동으로 다음 단계를 진행하지 마세요.

---

## Step 1: 요구사항정의서 → 업무기능분해도 (WBS)

### 입력 파싱

요구사항정의서 형식에 따라 파싱 방식이 다릅니다:

**엑셀 입력** — 가장 일반적. `references/requirements-columns.md`에 정의된 컬럼 매핑 참고:
```bash
python scripts/parse_requirements.py <input_file> --output wbs.json
```

**마크다운 입력** — `FR-XXX` 패턴으로 각 기능 요구사항을 추출.

**CSV 입력** — 헤더 행을 보고 컬럼 자동 매핑.

### 변환 로직

요구사항의 각 항목을 4개 레벨로 분해합니다:

| 레벨 | 설명 | 매핑 기준 |
|------|------|----------|
| Level 1 (업무영역) | 최상위 업무 영역 | 요구사항의 대분류 |
| Level 2 (업무기능) | 주요 기능 그룹 | 요구사항의 중분류 |
| Level 3 (세부기능) | 구현 모듈 수준 | 요구사항의 소분류 또는 기능 단위 |
| Level 4 (단위기능) | 최소 개발 단위 | 하나의 PR로 완료 가능한 수준 |

변환 시 고려할 점:
- 요구사항 하나가 여러 단위기능으로 분해될 수 있음
- 각 단위기능에 관련 레포를 추론하여 매핑 (예: "로그인 API" → backend-auth, "로그인 UI" → frontend-chat)
- 비기능 요구사항(NFR)은 관련 기능에 비고로 추가

### 출력

업무기능분해도를 엑셀 파일로 생성합니다:

```bash
python scripts/create_wbs_excel.py wbs.json --output 업무기능분해도.xlsx
```

템플릿 구조는 `assets/templates/` 디렉토리의 파일을 참고하세요. 엑셀 출력 시 openpyxl을 사용하고, 아래 형식을 따릅니다:

| No | Level 1 | Level 2 | Level 3 | Level 4 | 기능 설명 | 관련 레포 | 비고 |
|----|---------|---------|---------|---------|----------|----------|------|

헤더 행 스타일: 진한 파란 배경(#2B579A), 흰색 글자, 볼드체.
데이터 행: 홀짝 줄 교차 배경색, 테두리, 자동 열 너비 조정.

사용자에게 WBS를 보여주고 확인을 받으세요. 수정 요청이 있으면 반영 후 다음 단계로 진행합니다.

---

## Step 2: 업무기능분해도 → 상세기능설계서

WBS의 Level 3-4를 기반으로 프로세스별 상세 설계서를 생성합니다.

### 프로세스 ID 부여

프로세스 ID는 `PC_PLC_XXXX` 형식으로 자동 부여합니다:
- PC = 프로젝트 코드 (사용자에게 물어보거나 프로젝트명에서 추출)
- PLC = 하위 코드
- XXXX = 4자리 순번 (0101부터 시작, Level 2 그룹별로 100단위 구분)

### 상세기능설계서 구조

엑셀 파일로 생성하며, 두 종류의 시트가 있습니다:

**목차 탭**:
| No | 프로세스 ID | Level 1 | Level 2 | 프로세스명 | 담당자 | Step 수 | 예상 공수(일) |

**프로세스 탭** (프로세스별 1개 시트):
- 상단: 프로세스 정보 (ID, 이름, Input, Output, 설명, 요구사항 참조, 담당자)
- 하단: Step 상세 테이블

Step 상세 컬럼:
| Step 번호 | 역할 | Step명 | 수행방안 | 레포 | 개발 설계 상세 | 완료 조건 | 예상 공수(일) |

역할은 BE(백엔드), FE(프론트엔드), AI(AI/ML), FS(풀스택) 중 하나.

```bash
python scripts/create_dev_spec.py wbs.json --output 상세기능설계서.xlsx
```

API 명세와 일정은 이 설계서에 포함하지 않습니다 — 별도 문서로 관리합니다. (`references/api-specification-template.md`, `references/schedule-planning-input.md` 참고)

### 공수 산정 기준

| 크기 | 예상 공수 | 기준 |
|------|----------|------|
| S | 0.5일 | 단순 CRUD, 설정 변경 |
| M | 1일 | 일반적인 API + UI, 비즈니스 로직 포함 |
| L | 2일 | 복잡한 로직, 외부 API 연동, 상태 관리 |
| XL | 3일+ | AI 모델 연동, 실시간 처리, 대용량 데이터 |

사용자 확인 후 다음 단계로.

---

## Step 3: 상세기능설계서 → 태스크 생성

설계서의 각 Step을 GitHub Issue + 노션 칸반보드 태스크로 변환합니다.

### 태스크 생성 전 확인사항

사용자에게 반드시 확인:
1. **담당자 배정** — 설계서에 담당자가 비어있으면 누구를 배정할지
2. **우선순위** — 비즈니스 우선순위에 따른 조정
3. **GitHub org/repo** — 태스크를 생성할 GitHub Organization과 레포명
4. **노션 DB** — 연동할 노션 데이터베이스 ID

### GitHub Issue 생성

각 Step을 해당 레포에 Issue로 생성합니다:

```bash
gh issue create \
  --repo "{org}/{repo}" \
  --title "[{프로세스ID}_{Step번호}] {Step명}" \
  --body "$(cat <<'EOF'
## 설명
{수행방안}

## 개발 설계 상세
{개발 설계 상세}

## 완료 조건
{완료 조건을 체크리스트로}

## 메타정보
- **프로세스 ID**: {프로세스ID}
- **Step**: {Step번호}
- **역할**: {역할}
- **예상 공수**: {공수}일
- **선행 태스크**: {의존성}
EOF
)" \
  --label "priority:{priority}" \
  --assignee "{assignee}"
```

### 노션 칸반보드 생성

GitHub → 노션 동기화 워크플로우가 설정되어 있으면 자동 반영됩니다.
즉시 반영이 필요하거나 워크플로우가 없으면 Notion API로 직접 생성:

노션 DB에 필요한 프로퍼티:
- Name (title): Issue 제목
- Status (select): To Do / In Progress / In Review / Done
- Priority (select): High / Medium / Low
- Repository (select): 레포명
- Issue Number (number): GitHub Issue 번호
- Assignee (rich_text): 담당자
- Due Date (date): 시작일~마감일
- Labels (multi_select): 라벨
- GitHub URL (url): Issue 링크
- Last Sync (date): 동기화 시각 (양방향 동기화용)

```bash
# 노션 API 호출 예시 - 환경변수 필요: NOTION_API_KEY, NOTION_DATABASE_ID
python scripts/create_notion_tasks.py tasks.json
```

태스크 생성 결과를 사용자에게 보여주세요:
```
✅ 태스크 생성 완료!

GitHub Issues:
  backend-auth: #51, #52, #53
  backend-chat: #21, #22
  frontend-chat: #11, #12, #13

노션: 칸반보드에 8개 태스크 추가됨
  - To Do: 8개
  - 담당자: 이지용(3), 김철수(2), 박영희(3)
```

---

## Step 4: 일정표 생성

태스크의 예상 공수와 의존성, 팀원 정보를 기반으로 스프린트 계획을 자동 생성합니다.

### 팀원 정보 수집

`references/schedule-planning-input.md` 양식을 사용자에게 보여주고 작성하게 합니다.
필요한 정보:
- 팀원 이름, 역할, 투입률
- 휴무/부재 일정
- 외부 의존성 (API 발급, 디자인 전달 등)
- 우선순위/순서 제약

### 일정 산정 로직

1. 의존성 그래프(DAG)를 구성하여 토폴로지 정렬
2. 각 태스크를 담당자에게 배정 (역할 + 레포 기준)
3. 투입률을 반영한 실제 소요일 계산 (예: 1일 태스크, 50% 투입 → 2일)
4. 공휴일, 휴무 일정 제외
5. 버퍼 적용 (사용자가 지정한 비율)
6. 스프린트 단위로 그룹화

### 출력 형식

엑셀 파일로 생성:

```bash
python scripts/create_schedule.py tasks.json --team-info team.json --output 일정표.xlsx
```

시트 구성:
- **스프린트 계획**: 스프린트별 태스크 배분
- **팀원별 일정**: 간트 차트 형태 (날짜별 태스크 배정)
- **마일스톤**: 주요 기능 완료 목표일

리스크 분석도 포함:
```
⚠️ 리스크:
- Sprint 1 백엔드 공수 과다: 이지용 8일/10일 (80% 초과)
- Google OAuth 클라이언트 ID 미발급 시 04/03 착수 불가
- 프론트엔드 작업은 백엔드 API 완료 후 시작 → 병목 가능
```

---

## 개별 단계 실행

전체 파이프라인이 아닌 개별 단계만 실행할 수도 있습니다.

**"WBS 만들어줘"** → Step 1만 실행
**"설계서 만들어줘"** → Step 2만 실행 (WBS가 있으면 그것을 입력으로, 없으면 Step 1부터)
**"태스크 만들어줘"** → Step 3만 실행 (설계서가 있으면 그것을 입력으로)
**"일정 짜줘"** → Step 4만 실행 (태스크 목록이 있으면 그것을 입력으로)

이미 생성된 문서가 있으면 그것을 기반으로 해당 단계부터 시작합니다. 없으면 이전 단계를 먼저 실행할지 사용자에게 물어보세요.

---

## 태스크 업데이트 (수정 모드)

문서가 수정된 후 다시 실행하면, 기존 태스크와 비교하여 변경분만 처리합니다.

비교 기준: GitHub Issue 제목의 `[프로세스ID_Step번호]` 패턴.

```bash
gh issue list --repo {org}/{repo} --state all --json number,title,body --limit 500
```

변경 감지 결과:
- **CREATE**: 문서에는 있지만 GitHub에 없는 것 → 새로 생성
- **UPDATE**: 양쪽 다 있지만 내용이 다른 것 → 변경 내역을 보여주고 사용자 확인
- **REMOVED**: GitHub에는 있지만 문서에서 사라진 것 → 삭제하지 않고 알림

변경 사항을 사용자에게 보여주고 확인받은 후에만 반영합니다.

---

## GitHub ↔ 노션 양방향 동기화

태스크 생성 후 GitHub와 노션 사이의 양방향 동기화가 필요합니다.
동기화 워크플로우는 `references/sync-workflows.md`에서 상세 설정 방법을 확인하세요.

핵심 구조:
- **GitHub → 노션**: Webhook 기반 즉시 동기화 (GitHub Actions)
- **노션 → GitHub**: 5분 간격 폴링 (GitHub Actions cron)
- **충돌 방지**: `sync-bot` 라벨 + `Last Sync` 타임스탬프 비교
- **충돌 시**: 변경 거부 + 충돌 알림 (노션 코멘트, GitHub Issue 코멘트)

---

## 참고 문서

스킬 번들에 포함된 참고 문서들:

| 파일 | 내용 |
|------|------|
| `references/requirements-columns.md` | 요구사항정의서 엑셀 컬럼 매핑 가이드 |
| `references/api-specification-template.md` | API 명세서 템플릿 (별도 관리) |
| `references/schedule-planning-input.md` | 일정 계획 입력폼 |
| `references/sync-workflows.md` | GitHub ↔ 노션 동기화 워크플로우 설정 |
| `scripts/parse_requirements.py` | 요구사항정의서 파싱 스크립트 |
| `scripts/create_wbs_excel.py` | 업무기능분해도 엑셀 생성 |
| `scripts/create_dev_spec.py` | 상세기능설계서 엑셀 생성 |
| `scripts/create_schedule.py` | 일정표 엑셀 생성 |
| `scripts/create_notion_tasks.py` | 노션 태스크 생성 |
