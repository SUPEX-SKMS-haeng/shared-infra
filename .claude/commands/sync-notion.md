GitHub Issues 상태를 Notion 데이터베이스와 동기화합니다.

1. 현재 레포의 열린 이슈 목록 조회:
   ```
   gh issue list --json number,title,state,labels,assignees,createdAt,updatedAt --limit 100
   ```

2. 이슈 데이터를 정리해서 CSV 형식으로 출력:
   - 이슈번호, 제목, 상태, 라벨, 담당자, 생성일, 수정일

3. Notion API를 통해 동기화 (NOTION_API_KEY 환경변수 필요):
   - 새 이슈 → Notion 페이지 생성
   - 상태 변경 → Notion 상태 업데이트
   - 완료된 이슈 → Notion에서 "Done" 처리

환경변수:
- NOTION_API_KEY: Notion Integration 토큰
- NOTION_DATABASE_ID: 대상 데이터베이스 ID

$ARGUMENTS: `--dry-run` 옵션으로 실제 반영 없이 미리보기 가능
