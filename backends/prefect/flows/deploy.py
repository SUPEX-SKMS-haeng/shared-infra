"""
Deployment 등록 스크립트

flows/ 디렉토리의 플로우를 Worker 기반 deployment로 등록합니다.
Worker가 마운트된 /opt/prefect/flows 경로를 참조하여 실행합니다.

사용법:
    docker exec prefect-worker python /opt/prefect/flows/deploy.py
"""

from prefect import flow

# ── example.py:hello_flow 배포 ──
flow.from_source(
    source="/opt/prefect/flows",
    entrypoint="example.py:hello_flow",
).deploy(
    name="hello-schedule",
    work_pool_name="default-pool",
    cron="*/5 * * * *",  # 5분마다 실행
)
