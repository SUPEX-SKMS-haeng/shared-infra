# 요구사항정의서 엑셀 컬럼 매핑 가이드

요구사항정의서 엑셀 파일을 파싱할 때 컬럼 자동 매핑에 사용합니다.

## 표준 컬럼

| 컬럼명 (한글) | 영문 키 | 필수 | 설명 |
|--------------|---------|------|------|
| 요구사항 ID | req_id | Y | FR-001, NFR-001 등 |
| 요구사항구분 | req_type | Y | 기능(FR) / 비기능(NFR) |
| 대분류 | category_l1 | Y | Level 1 업무영역으로 매핑 |
| 중분류 | category_l2 | Y | Level 2 업무기능으로 매핑 |
| 소분류 | category_l3 | N | Level 3 세부기능으로 매핑 |
| 요구사항명 | req_name | Y | 기능명 |
| 요구사항 설명 | description | Y | 상세 설명 |
| 우선순위 | priority | N | High / Medium / Low |
| 상태 | status | N | 신규 / 변경 / 삭제 |
| 관리구분 | mgmt_type | N | 필수 / 선택 |
| 최종변경일 | updated_at | N | YYYY-MM-DD |
| 개발M/M | effort_mm | N | 예상 인월 (man-month) |
| 역할별 공수 | effort_by_role | N | BE:1, FE:0.5 형태 |
| 비고 | notes | N | 참고사항 |

## 컬럼 자동 인식

엑셀 파일의 헤더 행에서 위 컬럼명을 찾습니다. 정확히 일치하지 않아도 유사한 이름이면 매핑합니다:

- "요구사항ID", "요구사항 ID", "ID" → req_id
- "구분", "요구사항구분", "유형" → req_type
- "대분류", "업무영역", "L1" → category_l1
- "중분류", "업무기능", "L2" → category_l2
- "소분류", "세부기능", "L3" → category_l3
- "요구사항명", "기능명", "제목" → req_name
- "설명", "요구사항 설명", "상세설명" → description
- "우선순위", "Priority" → priority
- "공수", "M/M", "인월", "예상공수" → effort_mm

## WBS 변환 규칙

1. `대분류` → Level 1 (업무영역)
2. `중분류` → Level 2 (업무기능)
3. `소분류` → Level 3 (세부기능), 없으면 요구사항명에서 추론
4. Level 4 (단위기능) → Claude가 요구사항 설명을 분석하여 PR 단위로 분해

Level 4 분해 시 고려사항:
- 하나의 요구사항이 BE + FE 작업을 모두 포함하면 별도 단위기능으로 분리
- API 구현, UI 구현, 테스트를 각각 분리
- 외부 연동(OAuth, API 호출)은 별도 단위기능으로 분리
