PL이 개발자에게 할당할 GitHub Issue를 생성합니다.

$ARGUMENTS 에는 태스크 설명이 들어옵니다.

1. 태스크 설명을 분석해서 다음 정보를 구조화:
   - 제목 (한줄 요약)
   - 배경/목적
   - 상세 요구사항 (체크리스트)
   - 수용 기준 (Acceptance Criteria)
   - 참고 파일/코드 경로

2. 적절한 라벨 결정:
   - `feat`: 새 기능
   - `fix`: 버그 수정
   - `refactor`: 리팩토링
   - `test`: 테스트
   - `docs`: 문서화
   - 우선순위: `priority:high`, `priority:medium`, `priority:low`

3. GitHub Issue 생성:
   ```
   gh issue create --title "제목" --body "본문" --label "라벨1,라벨2"
   ```

4. 생성된 이슈 번호와 URL 출력

담당자 할당이 필요하면 `--assignee 깃헙유저명` 추가
