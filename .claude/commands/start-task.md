GitHub Issue 기반 태스크를 시작합니다.

1. `gh issue view $ARGUMENTS --json title,body,labels,assignees` 로 이슈 상세 확인
2. 이슈 내용을 분석해서 구현 계획 수립
3. 새 브랜치 생성: `feat/{앱약어}/{이슈번호}-{간단한설명}`
4. 이슈에 "🚀 작업 시작" 코멘트 추가: `gh issue comment $ARGUMENTS --body "🚀 작업을 시작합니다."`
5. 구현 계획을 사용자에게 보여주고 확인 후 진행

$ARGUMENTS 는 GitHub Issue 번호입니다.
