-- ============================================================
-- B6-1 · 옷장 관리 DB — 스키마 생성 스크립트
-- DB: SQLite 3 (파일 기반)
-- 실행: sqlite3 closet.db < schema.sql
-- ============================================================

-- [SQLite 전용] FK 검사는 기본이 OFF라서 연결마다 켜야 한다. (MySQL/PostgreSQL은 기본 ON)
PRAGMA foreign_keys = ON;

-- 다시 실행해도 되도록 자식 → 부모 순서로 삭제 (FK 때문에 순서 중요)
DROP TABLE IF EXISTS wear_log;
DROP TABLE IF EXISTS clothing;
DROP TABLE IF EXISTS category;
DROP TABLE IF EXISTS member;

-- ------------------------------------------------------------
-- 1) member : 옷장을 쓰는 회원 (1)
-- ------------------------------------------------------------
CREATE TABLE member (
    member_id  INTEGER PRIMARY KEY,                  -- [SQLite] INTEGER PRIMARY KEY = 자동 증가 rowid
    email      TEXT    NOT NULL UNIQUE,              -- UNIQUE: 같은 이메일로 중복 가입 방지
    nickname   TEXT    NOT NULL,                     -- NOT NULL: 빈 닉네임 방지
    created_at TEXT    NOT NULL DEFAULT CURRENT_DATE -- 'YYYY-MM-DD' 문자열로 저장 (SQLite에는 DATE 타입이 없음)
);

-- ------------------------------------------------------------
-- 2) category : 옷 종류 (상의/하의/아우터 ...) (1)
-- ------------------------------------------------------------
CREATE TABLE category (
    category_id INTEGER PRIMARY KEY,
    name        TEXT    NOT NULL UNIQUE              -- 카테고리 이름 중복 방지
);

-- ------------------------------------------------------------
-- 3) clothing : 등록한 옷 (N)  ← member 1:N, category 1:N
-- ------------------------------------------------------------
CREATE TABLE clothing (
    clothing_id  INTEGER PRIMARY KEY,
    member_id    INTEGER NOT NULL,                   -- 누구의 옷인지
    category_id  INTEGER NOT NULL,                   -- 어떤 종류인지
    name         TEXT    NOT NULL,
    color        TEXT    NOT NULL,
    season       TEXT    NOT NULL                    -- 두께/계절 구분
                 CHECK (season IN ('여름', '봄가을', '겨울', '사계절')),
    price        INTEGER                             -- 가격은 선택 입력이라 NULL 허용
                 CHECK (price IS NULL OR price >= 0),
    purchased_at TEXT,                               -- 'YYYY-MM-DD'
    status       TEXT    NOT NULL DEFAULT '보유'
                 CHECK (status IN ('보유', '처분')),
    FOREIGN KEY (member_id)   REFERENCES member(member_id),
    FOREIGN KEY (category_id) REFERENCES category(category_id)
);

-- ------------------------------------------------------------
-- 4) wear_log : 착용 기록 (N)  ← clothing 1:N
-- ------------------------------------------------------------
CREATE TABLE wear_log (
    wear_id     INTEGER PRIMARY KEY,
    clothing_id INTEGER NOT NULL,                    -- 어떤 옷을 입었는지
    worn_on     TEXT    NOT NULL,                    -- 입은 날짜 'YYYY-MM-DD'
    occasion    TEXT    NOT NULL DEFAULT '데일리',   -- 출근/약속/운동/데일리 ...
    FOREIGN KEY (clothing_id) REFERENCES clothing(clothing_id),
    UNIQUE (clothing_id, worn_on)                    -- 같은 옷을 같은 날 두 번 기록 방지
);
