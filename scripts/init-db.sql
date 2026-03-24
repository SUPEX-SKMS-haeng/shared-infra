-- ============================================================
-- 로컬 개발 DB 초기화
-- docker-compose.dev.yml의 postgres 컨테이너 최초 실행 시 자동 실행됩니다.
-- (볼륨이 이미 있으면 실행되지 않습니다 — 재실행하려면 docker compose down -v)
-- ============================================================

-- 기본 dev DB는 POSTGRES_DB=dev 로 자동 생성됨

-- 확장 (필요 시)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 개발 편의: 각 앱이 create_all()로 테이블을 자동 생성하므로
-- 여기서는 DB 레벨 설정만 합니다.

-- 타임존 설정
SET timezone = 'Asia/Seoul';

-- 로그 확인용
DO $$
BEGIN
  RAISE NOTICE '✅ dev 데이터베이스 초기화 완료 (timezone: Asia/Seoul)';
END $$;
