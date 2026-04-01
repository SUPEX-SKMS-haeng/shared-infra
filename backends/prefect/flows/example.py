"""
예시 Prefect Flow

이 파일은 파이프라인 코드 작성 패턴을 보여줍니다.
flows/ 디렉토리에 새 .py 파일을 추가하면 Worker가 접근 가능합니다.

배포 등록:
    prefect deployment build flows/example.py:hello_flow \
        --name "hello-schedule" \
        --cron "0 9 * * *" \
        --pool default-pool
"""

from prefect import flow, task


@task
def say_hello(name: str) -> str:
    message = f"Hello, {name}!"
    print(message)
    return message


@flow(name="hello-flow", log_prints=True)
def hello_flow(name: str = "World"):
    """간단한 예시 플로우"""
    result = say_hello(name)
    return result


if __name__ == "__main__":
    hello_flow()
