# shared-infra

공통 인프라 리소스 레포지토리입니다. 각 앱 레포지토리에서 git submodule로 참조합니다.

## 구조

```
shared-infra/
├── scripts/          # DB 시작 스크립트 등 공통 스크립트
├── kubernetes/       # K8s deployment, service, configmap 등
├── docs/             # 프로젝트 문서, 가이드라인, 프롬프트
├── data/             # 공유 데이터
├── backends/         # 비코드 인프라 서비스
│   ├── gateway/      # Traefik API Gateway
│   ├── milvus/       # Milvus Vector DB (Docker Compose)
│   └── phoenix/      # Arize Phoenix (Docker Compose)
├── .env.example      # 환경변수 템플릿
└── .github/          # 공통 GitHub Actions
```

## 사용법

각 앱 레포에서 submodule로 추가:
```bash
git submodule add https://github.com/agent-template-apps/shared-infra.git infra
git submodule update --init --recursive
```
