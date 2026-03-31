# shared-infra 서브모듈 일괄 업데이트

전체 앱 레포의 shared-infra 서브모듈을 최신으로 업데이트합니다.
새로운 스킬, 커맨드, 워크플로우가 추가되었을 때 실행하세요.

## 실행

```bash
./infra/scripts/update-all-repos.sh
```

특정 레포만 업데이트하려면:
```bash
./infra/scripts/update-all-repos.sh --repos "$ARGUMENTS"
```

$ARGUMENTS 가 비어있으면 전체 레포를 업데이트합니다.

## 실행 후

업데이트된 레포에서 서브모듈 변경이 있으면 자동으로 커밋됩니다.
각 레포에서 `git push`는 수동으로 해주세요.
