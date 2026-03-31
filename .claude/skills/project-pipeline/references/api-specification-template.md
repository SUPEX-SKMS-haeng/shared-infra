# API 명세서

> 프로젝트명: [프로젝트명] | 작성일: [YYYY-MM-DD] | 버전: v1.0
>
> 상세기능설계서의 Step별 API를 정의합니다.
> Claude Code에 이 문서를 주면 API 코드를 자동 생성할 수 있습니다.

---

## 공통 사항

### Base URL
```
개발: http://localhost:{port}/api/v1
스테이징: https://stg-api.example.com/api/v1
운영: https://api.example.com/api/v1
```

### 인증
```
Authorization: Bearer {access_token}
```

### 공통 응답 형식
```json
{
  "success": true,
  "data": { ... },
  "error": null
}
```

### 공통 에러 응답
```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "AUTH_001",
    "message": "인증 토큰이 만료되었습니다"
  }
}
```

### 공통 에러 코드

| 코드 | HTTP | 설명 |
|------|------|------|
| AUTH_001 | 401 | 인증 토큰 만료 |
| AUTH_002 | 401 | 유효하지 않은 토큰 |
| AUTH_003 | 403 | 권한 없음 |
| COMMON_001 | 400 | 필수 파라미터 누락 |
| COMMON_002 | 404 | 리소스를 찾을 수 없음 |
| COMMON_003 | 500 | 서버 내부 오류 |

---

## API 목록

### 설계서 참조: PC_PLC_0302 사용자-그룹 매핑 관리

| No | Method | Endpoint | 설명 | 레포 | 인증 |
|----|--------|----------|------|------|------|
| 1 | GET | /users/{user_id}/groups | 사용자의 매핑 그룹 목록 조회 | backend-base | 필요 |
| 2 | GET | /groups/{group_id}/users | 그룹에 매핑된 사용자 목록 조회 | backend-base | 필요 |
| 3 | POST | /users/{user_id}/groups | 사용자-그룹 매핑 추가 | backend-base | 필요 (관리자) |
| 4 | DELETE | /users/{user_id}/groups/{group_id} | 사용자-그룹 매핑 삭제 | backend-base | 필요 (관리자) |

---

### API-001: 사용자의 매핑 그룹 목록 조회

- **설계서 참조**: PC_PLC_0302_01
- **레포**: backend-base
- **담당자**: (담당자명)

```
GET /api/v1/users/{user_id}/groups
```

**Path Parameters**

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| user_id | integer | Y | 사용자 ID |

**Query Parameters**

| 이름 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| page | integer | N | 1 | 페이지 번호 |
| size | integer | N | 20 | 페이지 크기 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "group_id": 1,
        "group_name": "관리자 그룹",
        "mapped_at": "2026-03-01T09:00:00Z"
      }
    ],
    "total": 1,
    "page": 1,
    "size": 20
  }
}
```

**Error Responses**

| HTTP | 코드 | 상황 |
|------|------|------|
| 404 | USER_001 | 존재하지 않는 사용자 |

---

### API-002: 그룹에 매핑된 사용자 목록 조회

- **설계서 참조**: PC_PLC_0302_01
- **레포**: backend-base

```
GET /api/v1/groups/{group_id}/users
```

**Path Parameters**

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| group_id | integer | Y | 그룹 ID |

**Query Parameters**

| 이름 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| page | integer | N | 1 | 페이지 번호 |
| size | integer | N | 20 | 페이지 크기 |

**Response 200**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "user_id": 1,
        "user_name": "이지용",
        "employee_id": "SO12345",
        "mapped_at": "2026-03-01T09:00:00Z"
      }
    ],
    "total": 1,
    "page": 1,
    "size": 20
  }
}
```

---

### API-003: 사용자-그룹 매핑 추가

- **설계서 참조**: PC_PLC_0302_02
- **레포**: backend-base
- **권한**: 관리자만

```
POST /api/v1/users/{user_id}/groups
```

**Path Parameters**

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| user_id | integer | Y | 사용자 ID |

**Request Body**
```json
{
  "group_id": 1
}
```

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| group_id | integer | Y | 매핑할 그룹 ID |

**Response 201**
```json
{
  "success": true,
  "data": {
    "user_id": 1,
    "group_id": 1,
    "mapped_at": "2026-04-01T10:30:00Z"
  }
}
```

**Error Responses**

| HTTP | 코드 | 상황 |
|------|------|------|
| 404 | USER_001 | 존재하지 않는 사용자 |
| 404 | GROUP_001 | 존재하지 않는 그룹 |
| 409 | MAPPING_001 | 이미 매핑된 사용자-그룹 |
| 403 | AUTH_003 | 관리자 권한 없음 |

---

### API-004: 사용자-그룹 매핑 삭제

- **설계서 참조**: PC_PLC_0302_03
- **레포**: backend-base
- **권한**: 관리자만

```
DELETE /api/v1/users/{user_id}/groups/{group_id}
```

**Path Parameters**

| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| user_id | integer | Y | 사용자 ID |
| group_id | integer | Y | 그룹 ID |

**Response 204**
```
No Content
```

**Error Responses**

| HTTP | 코드 | 상황 |
|------|------|------|
| 404 | MAPPING_002 | 존재하지 않는 매핑 |
| 403 | AUTH_003 | 관리자 권한 없음 |

---

## 작성 가이드

각 API 항목에 포함할 내용:

1. **설계서 참조** — 상세기능설계서의 Step 번호 (PC_PLC_XXXX_XX)
2. **Method + Endpoint** — RESTful 규칙 준수
3. **Parameters** — Path, Query, Request Body
4. **Response** — 성공 응답 + 에러 응답
5. **레포** — 구현 대상 레포
6. **권한** — 인증 필요 여부, 역할 제한

Claude Code에 이 문서를 주면:
- `@task-planner`로 API별 태스크 분해
- 코드 생성 시 이 스펙 기반으로 엔드포인트 구현
- `@test-runner`로 API 테스트 자동 생성
