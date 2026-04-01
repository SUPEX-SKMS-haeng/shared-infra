# Prefect 스케줄러

Prefect Server + Worker 기반 워크플로우 오케스트레이션.

## 아키텍처

```
┌─────────────────────────────────────────────────┐
│  Prefect Server (:4200)                         │
│  - API 서버 + Web UI                            │
│  - Deployment/Schedule 관리                     │
│  - Flow Run 상태 추적                           │
└────────────────────┬────────────────────────────┘
                     │ polling
┌────────────────────▼────────────────────────────┐
│  Worker (1~N개)                                  │
│  - default-pool에서 flow run 가져감              │
│  - /opt/prefect/flows 경로의 코드 실행           │
│  - 수평 확장 가능                                │
└────────────────────┬────────────────────────────┘
                     │ mount
┌────────────────────▼────────────────────────────┐
│  Shared Volume (flows/)                          │
│  - deploy.py : deployment 등록 스크립트          │
│  - example.py : flow 코드                        │
│  - 새 .py 추가 → deploy.py에 등록 → 자동 배포   │
└─────────────────────────────────────────────────┘
```

## 디렉토리 구조

```
prefect/
├── docker-compose.yml              # 로컬 개발용 (Docker)
├── deploy/                         # K8s 매니페스트
│   ├── prefect-server-deploy.yml   #   Server Deployment
│   ├── prefect-server-svc.yml      #   Server Service (ClusterIP :4200)
│   ├── prefect-worker-deploy.yml   #   Worker Deployment (initContainer로 자동 배포)
│   └── prefect-flows-job.yml       #   Git → PVC 동기화 Job
├── flows/                          # 파이프라인 코드 (shared volume)
│   ├── deploy.py                   #   deployment 등록 스크립트
│   └── example.py                  #   예시 flow
└── README.md
```

---

## Flow 작성 가이드

### 1. Flow 코드 작성

`flows/` 디렉토리에 Python 파일을 추가합니다.

```python
from prefect import flow, task

@task
def extract_data():
    ...

@task
def transform_data(raw):
    ...

@flow(name="my-pipeline", log_prints=True)
def my_pipeline():
    raw = extract_data()
    result = transform_data(raw)
    return result

if __name__ == "__main__":
    my_pipeline()
```

### 2. Deployment 등록

`flows/deploy.py`에 새 flow의 deployment를 추가합니다.

```python
from prefect import flow

# ── 기존 ──
flow.from_source(
    source="/opt/prefect/flows",
    entrypoint="example.py:hello_flow",
).deploy(
    name="hello-schedule",
    work_pool_name="default-pool",
    cron="*/5 * * * *",
)

# ── 새로 추가 ──
flow.from_source(
    source="/opt/prefect/flows",
    entrypoint="my_pipeline.py:my_pipeline",
).deploy(
    name="my-pipeline-daily",
    work_pool_name="default-pool",
    cron="0 9 * * *",  # 매일 09:00
)
```

### 3. 외부 서비스 호출

```python
import httpx

@task
def call_backend():
    # Docker: host.docker.internal:{port}
    # K8s: {service-name}-svc:{port}
    resp = httpx.get("http://host.docker.internal:8080/api/v1/health")
    return resp.json()
```

---

## Docker 기반 (로컬 개발)

### 시작

```bash
cd shared-infra/backends/prefect
docker compose up -d
```

Worker가 시작되면 자동으로:
1. `default-pool` Work Pool 생성
2. `deploy.py` 실행 → Deployment 등록
3. Worker 시작 → 스케줄에 따라 flow 실행

### 확인

```bash
# 컨테이너 상태
docker compose ps

# Worker 로그 (deployment 등록 + 실행 로그)
docker compose logs -f worker

# Prefect UI
open http://localhost:4200
```

### Worker 수평 확장

```bash
docker compose up -d --scale worker=4
```

### 수동 실행

```bash
# CLI로 flow run 트리거
docker compose exec worker prefect deployment run 'hello-flow/hello-schedule'

# 직접 실행 (deployment 없이)
docker compose exec worker python /opt/prefect/flows/example.py
```

### Flow 코드 수정 반영

`flows/` 디렉토리는 bind mount이므로 호스트에서 수정하면 바로 반영됩니다.
deployment 설정(스케줄 등)을 변경한 경우 Worker를 재시작합니다.

```bash
docker compose restart worker
```

### 중지

```bash
docker compose down       # 컨테이너 중지
docker compose down -v    # 데이터까지 삭제
```

---

## Kubernetes 기반 (운영)

### 사전 준비

Git 토큰 Secret을 생성합니다 (최초 1회).

```bash
kubectl create secret generic git-credentials -n agent \
  --from-literal=token=ghp_xxxxxxxxxxxx
```

### 배포 순서

#### 1. Server 배포

```bash
kubectl apply -f deploy/prefect-server-deploy.yml
kubectl apply -f deploy/prefect-server-svc.yml

# Server Ready 확인
kubectl wait --for=condition=available deployment/prefect-server -n agent --timeout=120s
```

#### 2. Flow 코드를 PVC에 동기화

Git에서 `flows/` 디렉토리를 clone하여 PVC에 복사합니다.

```bash
kubectl apply -f deploy/prefect-flows-job.yml

# Job 완료 확인
kubectl wait --for=condition=complete job/prefect-flows-sync -n agent --timeout=60s
```

#### 3. Worker 배포

Worker가 시작되면 initContainer가 자동으로 deployment를 등록합니다.

```bash
kubectl apply -f deploy/prefect-worker-deploy.yml
```

### Worker 수평 확장

```bash
kubectl scale deployment prefect-worker -n agent --replicas=4
```

### Flow 코드 업데이트

flow 코드를 수정하고 Git에 push한 뒤:

```bash
# 1. PVC 동기화 (Git → PVC)
kubectl delete job prefect-flows-sync -n agent --ignore-not-found
kubectl apply -f deploy/prefect-flows-job.yml

# 2. Worker 재시작 (initContainer가 deploy.py 다시 실행)
kubectl rollout restart deployment prefect-worker -n agent
```

### 수동 실행

```bash
# Worker 파드에서 flow run 트리거
kubectl exec -it deployment/prefect-worker -n agent -- \
  prefect deployment run 'hello-flow/hello-schedule'
```

### 로그 확인

```bash
# Server
kubectl logs deployment/prefect-server -n agent -f

# Worker
kubectl logs deployment/prefect-worker -n agent -f

# Flow 동기화 Job
kubectl logs job/prefect-flows-sync -n agent
```

### UI 접근

```bash
kubectl port-forward svc/prefect-server-svc 4200:4200 -n agent
open http://localhost:4200
```

---

## 스케줄 표현식 참고

| 표현식 | 의미 |
|--------|------|
| `*/5 * * * *` | 5분마다 |
| `0 * * * *` | 매시간 정각 |
| `0 9 * * *` | 매일 09:00 |
| `0 9 * * 1-5` | 평일 09:00 |
| `0 0 1 * *` | 매월 1일 00:00 |

`deploy.py`에서 `cron` 대신 `interval=3600` (초 단위)도 사용 가능합니다.
