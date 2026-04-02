# 커밋 메시지 규칙

## 형식

```
{type}({scope}): {한글 요약}

- {변경 내용 1}
- {변경 내용 2}
- {변경 내용 3}

Refs #{이슈번호}
```

## 제목 규칙

- **50자 이내**
- 형식: `{type}({scope}): {한글 요약}`

### type

| type       | 용도               |
| ---------- | ------------------ |
| `feat`     | 새 기능 추가       |
| `fix`      | 버그 수정          |
| `refactor` | 리팩토링           |
| `chore`    | 빌드/설정 변경     |
| `docs`     | 문서 수정          |
| `test`     | 테스트 추가/수정   |
| `style`    | 코드 스타일/포맷팅 |

### scope

- 앱 약어: `auth`, `base`, `chat`, `llm-gw`, `mcp`, `admin`
- 또는 모듈명: `oauth`, `api`, `db`, `ui` 등
- 변경 범위가 여러 앱에 걸치면 가장 핵심적인 것 하나를 선택

## 본문 규칙

- 변경 내용을 항목별(`-`)로 정리
- 한글로 작성
- "무엇을" 했는지 구체적으로 기술

## 꼬리 규칙

- `Refs #{이슈번호}` 로 관련 이슈 연결
- 이슈가 없으면 생략 가능

## 좋은 예시

```
feat(oauth): Google OAuth2 로그인 구현

- /api/v1/auth/google 엔드포인트 추가
- GoogleOAuthService 서비스 레이어 구현
- JWT 토큰 발급 로직 연동
- 관련 단위 테스트 추가

Refs #42
```

```
fix(chat): WebSocket 연결 끊김 후 재연결 실패 수정

- heartbeat 타이머 초기화 누락 수정
- 재연결 시 이전 세션 토큰 재사용하도록 변경

Refs #87
```

## 나쁜 예시

```
# BAD: 영어, scope 없음, 너무 모호
update code

# BAD: 제목이 너무 김
feat(auth): Google OAuth2 로그인을 구현하고 JWT 토큰 발급 로직을 연동하며 관련 테스트도 추가함

# BAD: type이 잘못됨 (버그 수정인데 feat 사용)
feat(chat): WebSocket 버그 수정
```
