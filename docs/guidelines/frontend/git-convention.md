# Git 컨벤션

## 브랜치 네이밍

```
{type}/{ticket-id}-{short-description}
```

예시:
- `feat/FE-123-user-profile-page`
- `fix/FE-456-login-redirect-bug`
- `chore/FE-789-update-dependencies`

type: `feat` | `fix` | `refactor` | `chore` | `docs` | `hotfix`

## 커밋 메시지 포맷

```
{type}: {작업 내용} ({ticket-id})
```

예시:
- `feat: 사용자 목록 페이지 추가 (FE-123)`
- `fix: 로그인 후 리다이렉트 경로 수정 (FE-456)`
- `refactor: UserList 비즈니스 로직 훅으로 분리 (FE-789)`

### type 기준

| type | 기준 |
|------|------|
| `feat` | 새 기능 또는 새 파일 |
| `fix` | 버그 수정 |
| `refactor` | 동작 변경 없는 코드 개선 |
| `chore` | 설정, 패키지, 빌드 변경 |
| `docs` | 문서만 변경 |
| `style` | 마크업/스타일만 변경 |
| `hotfix` | 프로덕션 긴급 수정 |

### 작성 기준

- 한국어로 작성
- "무엇을"이 아닌 "왜/어떤 목적으로" 중심
- 제목 50자 이내

## 절대 금지

- `main`, `develop` 브랜치 직접 커밋
- `.env`, `*.local`, secrets 포함 파일 커밋
