#!/usr/bin/env python3
"""
노션 태스크 생성 스크립트
JSON 형식의 태스크 목록을 노션 칸반보드 DB에 추가합니다.

사용법:
  python create_notion_tasks.py tasks.json

환경변수 필요:
  NOTION_API_KEY: 노션 Integration 토큰
  NOTION_DATABASE_ID: 태스크 DB ID
"""

import argparse
import json
import os
import sys
import time

try:
    import urllib.request
    import urllib.error
except ImportError:
    pass


NOTION_API_URL = "https://api.notion.com/v1"
NOTION_VERSION = "2022-06-28"


def notion_request(method: str, endpoint: str, data: dict = None,
                   api_key: str = "") -> dict:
    """노션 API 호출 헬퍼"""
    url = f"{NOTION_API_URL}{endpoint}"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Notion-Version": NOTION_VERSION,
        "Content-Type": "application/json",
    }

    body = json.dumps(data).encode("utf-8") if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        print(f"  ❌ Notion API 오류 ({e.code}): {error_body}")
        return {"error": True, "status": e.code, "message": error_body}


def search_existing_task(api_key: str, db_id: str,
                         issue_number: int, repo: str) -> dict | None:
    """노션 DB에서 기존 태스크를 검색합니다."""
    result = notion_request("POST", f"/databases/{db_id}/query", {
        "filter": {
            "and": [
                {"property": "Issue Number", "number": {"equals": issue_number}},
                {"property": "Repository", "select": {"equals": repo}},
            ]
        }
    }, api_key)

    if result.get("results"):
        return result["results"][0]
    return None


def create_task_page(api_key: str, db_id: str, task: dict) -> dict:
    """노션 DB에 태스크 페이지를 생성합니다."""
    properties = {
        "Name": {"title": [{"text": {"content": task.get("title", "")}}]},
        "Status": {"select": {"name": task.get("status", "To Do")}},
        "Priority": {"select": {"name": task.get("priority", "Medium")}},
        "Repository": {"select": {"name": task.get("repo", "")}},
        "Assignee": {"rich_text": [{"text": {"content": task.get("assignee", "")}}]},
    }

    if task.get("issue_number"):
        properties["Issue Number"] = {"number": task["issue_number"]}

    if task.get("github_url"):
        properties["GitHub URL"] = {"url": task["github_url"]}

    if task.get("start_date") or task.get("end_date"):
        date_obj = {}
        if task.get("start_date"):
            date_obj["start"] = task["start_date"]
        if task.get("end_date"):
            date_obj["end"] = task["end_date"]
        properties["Due Date"] = {"date": date_obj}

    if task.get("labels"):
        properties["Labels"] = {
            "multi_select": [{"name": l} for l in task["labels"]]
        }

    properties["Last Sync"] = {"date": {"start": get_iso_now()}}

    return notion_request("POST", "/pages", {
        "parent": {"database_id": db_id},
        "properties": properties,
    }, api_key)


def get_iso_now() -> str:
    """현재 시각을 ISO 형식으로 반환합니다."""
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).isoformat()


def main():
    parser = argparse.ArgumentParser(description="노션 태스크 생성")
    parser.add_argument("input_file", help="태스크 JSON 파일")
    parser.add_argument("--dry-run", action="store_true", help="실제 API 호출 없이 시뮬레이션")
    args = parser.parse_args()

    api_key = os.environ.get("NOTION_API_KEY", "")
    db_id = os.environ.get("NOTION_DATABASE_ID", "")

    if not args.dry_run and (not api_key or not db_id):
        print("❌ 환경변수 필요: NOTION_API_KEY, NOTION_DATABASE_ID")
        print("   export NOTION_API_KEY='secret_xxx'")
        print("   export NOTION_DATABASE_ID='xxx-xxx-xxx'")
        sys.exit(1)

    with open(args.input_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    tasks = data.get("tasks", [])
    print(f"📋 {len(tasks)}개 태스크를 노션에 생성합니다...")

    created = 0
    skipped = 0
    errors = 0

    for task in tasks:
        title = task.get("title", task.get("id", "Unknown"))
        issue_num = task.get("issue_number")
        repo = task.get("repo", "")

        if args.dry_run:
            print(f"  [DRY RUN] 생성: {title} ({repo})")
            created += 1
            continue

        # 기존 태스크 확인
        if issue_num and repo:
            existing = search_existing_task(api_key, db_id, issue_num, repo)
            if existing:
                print(f"  ⏭️ 이미 존재: {title} (Issue #{issue_num})")
                skipped += 1
                continue

        result = create_task_page(api_key, db_id, task)
        if result.get("error"):
            errors += 1
        else:
            print(f"  ✅ 생성: {title}")
            created += 1

        # API 속도 제한 (3req/sec)
        time.sleep(0.4)

    print(f"\n결과: 생성 {created}개, 스킵 {skipped}개, 오류 {errors}개")


if __name__ == "__main__":
    main()
