-- ============================================================
-- B6-1 · 옷장 관리 DB — 핵심 쿼리 15개
-- 기본 조회 4 · 조인 4 · 집계 3 · 서브쿼리 1 · 수정/삭제 2 · 인덱스 1
-- 실행: sqlite3 closet.db < queries.sql  (schema.sql → seed.sql 적용 후)
--
-- 기준일: 모든 "최근 N일" 쿼리는 2026-10-14를 기준일로 고정해서
--         언제 실행해도 같은 결과가 나오게 했다. (date('now')를 쓰면 결과가 매일 달라짐)
-- [SQLite 전용] 표시가 있는 쿼리는 date() 같은 SQLite 함수를 쓴 것이다.
-- ============================================================

PRAGMA foreign_keys = ON;

-- ===================== 기본 조회 (4) =====================

-- [Q01] 기본 조회 · 가을에 입는 '봄가을' 옷 중 비싼 순 TOP 5 (WHERE + ORDER BY + LIMIT)
SELECT clothing_id, name, color, price
FROM clothing
WHERE season = '봄가을'
  AND status = '보유'
  AND price IS NOT NULL            -- NULL은 DB마다 정렬 위치가 달라서 미리 제외
ORDER BY price DESC
LIMIT 5;

-- [Q02] 기본 조회 · 이름에 '셔츠'가 들어간 옷을 최근 구매순으로 검색 (LIKE + ORDER BY)
SELECT clothing_id, name, color, purchased_at
FROM clothing
WHERE name LIKE '%셔츠%'
ORDER BY purchased_at DESC;

-- [Q03] 기본 조회 · 최근 30일(기준일 2026-10-14) 착용 기록 최신 10건 (WHERE 날짜 범위 + LIMIT)
-- [SQLite 전용] date('2026-10-14', '-30 days')  ※ MySQL: DATE_SUB('2026-10-14', INTERVAL 30 DAY)
SELECT wear_id, clothing_id, worn_on, occasion
FROM wear_log
WHERE worn_on >= date('2026-10-14', '-30 days')
ORDER BY worn_on DESC, wear_id DESC
LIMIT 10;

-- [Q04] 기본 조회 · 가격을 입력하지 않은 옷 찾기 (IS NULL — '= NULL'은 동작하지 않음)
SELECT clothing_id, name, purchased_at, status
FROM clothing
WHERE price IS NULL
ORDER BY purchased_at;

-- ======================= 조인 (4) =======================

-- [Q05] INNER JOIN · 모아(1번 회원)의 옷을 주인·카테고리 이름과 함께 조회 (3개 테이블 조인)
SELECT m.nickname, cat.name AS category, c.name AS clothing_name, c.color
FROM clothing c
INNER JOIN member   m   ON m.member_id    = c.member_id
INNER JOIN category cat ON cat.category_id = c.category_id
WHERE m.member_id = 1
ORDER BY cat.category_id, c.clothing_id;

-- [Q06] INNER JOIN · 최근 4일(2026-10-10~) 착용 기록에 옷 이름 붙여 보기
-- [SQLite 전용] date() 함수
SELECT w.worn_on, c.name AS clothing_name, w.occasion
FROM wear_log w
INNER JOIN clothing c ON c.clothing_id = w.clothing_id
WHERE w.worn_on >= date('2026-10-14', '-4 days')
ORDER BY w.worn_on DESC, c.name;

-- [Q07] LEFT JOIN · 보유 중이지만 착용 기록이 한 번도 없는 옷 (안 입는 옷 찾기)
SELECT c.clothing_id, c.name, m.nickname, c.purchased_at
FROM clothing c
LEFT JOIN wear_log w ON w.clothing_id = c.clothing_id
INNER JOIN member m  ON m.member_id   = c.member_id
WHERE w.wear_id IS NULL            -- 짝이 없는(=기록 없는) 옷만 남김
  AND c.status = '보유'
ORDER BY c.purchased_at;

-- [Q08] LEFT JOIN · 아직 옷을 한 벌도 등록하지 않은 회원 찾기
SELECT m.member_id, m.nickname, m.created_at
FROM member m
LEFT JOIN clothing c ON c.member_id = m.member_id
WHERE c.clothing_id IS NULL;

-- ======================= 집계 (3) =======================

-- [Q09] 집계(COUNT + AVG + GROUP BY) · 카테고리별 옷 개수와 평균 가격 (가격 NULL은 AVG에서 자동 제외)
SELECT cat.name AS category,
       COUNT(*) AS clothing_count,
       CAST(ROUND(AVG(c.price)) AS INTEGER) AS avg_price
FROM category cat
INNER JOIN clothing c ON c.category_id = cat.category_id
GROUP BY cat.category_id, cat.name
ORDER BY clothing_count DESC, cat.category_id;

-- [Q10] 집계(COUNT + SUM + GROUP BY + HAVING) · 보유 옷 구매금액 합계가 10만 원 이상인 회원
SELECT m.nickname,
       COUNT(*)     AS owned_count,
       SUM(c.price) AS total_price
FROM member m
INNER JOIN clothing c ON c.member_id = m.member_id
WHERE c.status = '보유'
GROUP BY m.member_id, m.nickname
HAVING SUM(c.price) >= 100000     -- 그룹이 만들어진 뒤 거르는 조건은 WHERE가 아니라 HAVING
ORDER BY total_price DESC;

-- [Q11] 집계(COUNT + GROUP BY) + 랭킹 · 가장 많이 입은 옷 TOP 5
SELECT c.name AS clothing_name,
       COUNT(*) AS wear_count
FROM wear_log w
INNER JOIN clothing c ON c.clothing_id = w.clothing_id
GROUP BY c.clothing_id, c.name
ORDER BY wear_count DESC, c.clothing_id   -- 동점이면 id순으로 고정
LIMIT 5;

-- ===================== 서브쿼리 (1) =====================

-- [Q12] 서브쿼리 · 전체 옷 평균 가격보다 비싼 옷 (WHERE 안의 스칼라 서브쿼리)
SELECT clothing_id, name, price
FROM clothing
WHERE price > (SELECT AVG(price) FROM clothing)
ORDER BY price DESC;

-- ================== 데이터 수정 / 삭제 (2) ==================
-- ※ Q13 → Q14 순서로 이어지는 "옷장 정리" 시나리오 (데이터가 실제로 바뀜)

-- [Q13] UPDATE · 구매 1년이 넘었는데 착용 기록이 0건인 보유 옷을 '처분' 상태로 변경 (NOT EXISTS 서브쿼리 + 변경 확인)
-- [SQLite 전용] date('2026-10-14', '-1 year')
UPDATE clothing
SET status = '처분'
WHERE status = '보유'
  AND purchased_at < date('2026-10-14', '-1 year')
  AND NOT EXISTS (SELECT 1 FROM wear_log w WHERE w.clothing_id = clothing.clothing_id);

-- (확인) 처분 상태인 옷 — 10, 27, 35번이 새로 바뀌고 19, 23번은 원래 처분 상태
SELECT clothing_id, name, status FROM clothing WHERE status = '처분' ORDER BY clothing_id;

-- [Q14] DELETE · '처분'이면서 착용 기록이 없는 옷만 삭제 (기록이 있는 19번은 FK 때문에 지우면 에러 → 조건으로 제외)
DELETE FROM clothing
WHERE status = '처분'
  AND clothing_id NOT IN (SELECT clothing_id FROM wear_log);

-- (확인) 삭제 후 남은 처분 옷과 전체 옷 개수 — 19번만 남고 총 36벌
-- [DB별 문법] GROUP_CONCAT: MySQL도 동일, PostgreSQL은 STRING_AGG
SELECT (SELECT COUNT(*) FROM clothing) AS total_clothing,
       (SELECT GROUP_CONCAT(clothing_id) FROM clothing WHERE status = '처분') AS disposed_ids;

-- ======================== 인덱스 (1) ========================

-- [Q15] INDEX · 날짜 범위 조회가 잦은 wear_log.worn_on에 인덱스 생성 (적용 전/후 실행 계획 비교)
-- 적용 이유: 착용 기록은 계속 쌓이고 "최근 N일" 날짜 범위 조회가 가장 잦아서, 전체 스캔 대신 인덱스로 찾도록 worn_on에 건다.
-- 참고: UNIQUE(clothing_id, worn_on) 인덱스는 clothing_id가 앞이라 worn_on 단독 검색에는 쓰이지 않는다.
-- [SQLite 전용] EXPLAIN QUERY PLAN  ※ MySQL/PostgreSQL은 EXPLAIN
EXPLAIN QUERY PLAN
SELECT * FROM wear_log WHERE worn_on >= '2026-10-01';

CREATE INDEX idx_wear_log_worn_on ON wear_log (worn_on);

EXPLAIN QUERY PLAN
SELECT * FROM wear_log WHERE worn_on >= '2026-10-01';
