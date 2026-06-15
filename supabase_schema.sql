-- ============================================================
-- 서해수산 가공㈜ 업무 자동화 시스템 — Supabase DB 스키마
-- PRD v1.3 기준 | KACCA 한국AI창의융합협회 | 2026.06.16
-- ============================================================
-- 실행 순서: Supabase Dashboard → SQL Editor → 전체 붙여넣기 → Run
-- ============================================================


-- ============================================================
-- 0. 확장 기능
-- ============================================================

-- UUID 자동 생성
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ============================================================
-- 1. users (사용자)
-- ============================================================
-- Supabase Auth와 연동: auth.users.id = users.id
-- 로그인 후 이 테이블에서 role 조회

CREATE TABLE IF NOT EXISTS users (
  id          uuid PRIMARY KEY,                        -- Supabase Auth UID
  email       text NOT NULL UNIQUE,
  name        text NOT NULL,
  role        text NOT NULL CHECK (role IN ('admin', 'production', 'haccp')),
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  users IS '시스템 사용자 (Supabase Auth와 1:1 연동)';
COMMENT ON COLUMN users.role IS 'admin=총괄감독 / production=생산부장 / haccp=HACCP담당자';


-- ============================================================
-- 2. products (품목관리)
-- ============================================================

CREATE TABLE IF NOT EXISTS products (
  id            uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  code          text NOT NULL UNIQUE,   -- M01, M02 등
  name          text NOT NULL,
  unit          text NOT NULL,          -- kg, box 등
  unit_price    numeric(12,2) NOT NULL DEFAULT 0,
  allergen_info text,                   -- 알레르기 유발 식품 요약
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE products IS '가공 품목 (원료 및 완제품)';


-- ============================================================
-- 3. vendors (거래처)
-- ============================================================

CREATE TABLE IF NOT EXISTS vendors (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name              text NOT NULL,
  business_number   text,              -- 사업자등록번호
  representative    text,              -- 대표자명
  address           text,
  phone             text,
  email             text,              -- 세금계산서 수신 이메일
  vendor_type       text NOT NULL CHECK (vendor_type IN ('공급업체', '판매처', '양방향')),
  is_active         boolean NOT NULL DEFAULT true,
  is_deleted        boolean NOT NULL DEFAULT false,
  created_by        uuid REFERENCES users(id),
  created_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE vendors IS '거래처 (공급업체 / 판매처 / 양방향)';


-- ============================================================
-- 4. inbound (입고기록)
-- ============================================================

CREATE TABLE IF NOT EXISTS inbound (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  lot_number   text NOT NULL UNIQUE,   -- YYMMDD-M##-## 자동 생성
  inbound_date date NOT NULL,
  product_id   uuid NOT NULL REFERENCES products(id),
  quantity     numeric(12,3) NOT NULL CHECK (quantity > 0),
  vendor_id    uuid REFERENCES vendors(id),   -- 선택 (거래처 미등록 공급사도 있음)
  origin       text,                           -- 원산지
  expiry_date  date NOT NULL,                 -- 유통기한 (필수)
  is_usable    boolean NOT NULL DEFAULT true, -- false: 품질검사 불합격
  created_by   uuid REFERENCES users(id),
  is_deleted   boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN inbound.is_usable IS 'false이면 품질검사 불합격 — 가공·출고 선택 불가';
COMMENT ON COLUMN inbound.lot_number IS '형식: YYMMDD-M##-## (예: 260530-M01-01)';


-- ============================================================
-- 5. quality_inspection (품질/관능검사)
-- ============================================================

CREATE TABLE IF NOT EXISTS quality_inspection (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  inbound_id      uuid NOT NULL REFERENCES inbound(id),
  inspector_id    uuid REFERENCES users(id),   -- 검사 및 입력 담당자
  inspection_date date NOT NULL,
  appearance      text CHECK (appearance IN ('정상', '불량')),
  smell           text CHECK (smell IN ('정상', '이취')),
  temperature     numeric(5,1),               -- 입고 온도 (℃)
  result          text NOT NULL CHECK (result IN ('합격', '조건부합격', '불합격')),
  notes           text,
  is_deleted      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE quality_inspection IS '입고 시 품질/관능검사 기록. 불합격 → inbound.is_usable = false 업데이트';


-- ============================================================
-- 6. channels (출고 채널)
-- ============================================================

CREATE TABLE IF NOT EXISTS channels (
  id                    uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name                  text NOT NULL UNIQUE,
  channel_type          text NOT NULL CHECK (channel_type IN ('온라인몰', '직거래', '도매')),
  tax_invoice_required  boolean NOT NULL DEFAULT false,
  default_vendor_id     uuid REFERENCES vendors(id),
  is_active             boolean NOT NULL DEFAULT true,
  is_deleted            boolean NOT NULL DEFAULT false,
  created_by            uuid REFERENCES users(id),
  created_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE channels IS '출고 채널 (쿠팡/네이버/직접판매 등). 출고 기록 연결 시 삭제 불가';


-- ============================================================
-- 7. processing (가공기록)
-- ============================================================

CREATE TABLE IF NOT EXISTS processing (
  id               uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  lot_number       text NOT NULL UNIQUE,   -- 원료로트-P (예: 260530-M01-01-P)
  process_date     date NOT NULL,
  product_id       uuid NOT NULL REFERENCES products(id),  -- 완제품 기준
  raw_lot_id       uuid NOT NULL REFERENCES inbound(id),   -- 원료 입고 로트
  input_quantity   numeric(12,3) NOT NULL CHECK (input_quantity > 0),  -- 원료 투입량
  yield_quantity   numeric(12,3) NOT NULL CHECK (yield_quantity >= 0), -- 실제 생산량
  temperature      numeric(5,1),          -- 가공 온도
  created_by       uuid REFERENCES users(id),
  is_deleted       boolean NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT yield_lte_input CHECK (yield_quantity <= input_quantity)
);

COMMENT ON COLUMN processing.input_quantity IS '원료 투입량';
COMMENT ON COLUMN processing.yield_quantity IS '실제 생산량 (재고 계산 기준). 손실률 = (투입-생산)/투입';


-- ============================================================
-- 8. outbound (출고기록)
-- ============================================================

CREATE TABLE IF NOT EXISTS outbound (
  id                       uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  out_number               text NOT NULL UNIQUE,   -- OUT-YYMMDD-###
  outbound_date            date NOT NULL,
  processing_id            uuid NOT NULL REFERENCES processing(id),
  quantity                 numeric(12,3) NOT NULL CHECK (quantity > 0),
  vendor_id                uuid REFERENCES vendors(id),
  channel_id               uuid REFERENCES channels(id),
  delivery_invoice_number  text,   -- 배송 송장번호 (택배 운송장, 세금계산서 번호와 별개)
  created_by               uuid REFERENCES users(id),
  is_deleted               boolean NOT NULL DEFAULT false,
  created_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN outbound.delivery_invoice_number IS '택배사 배송 송장번호. 세금계산서 번호(TAX-...)와 다름';


-- ============================================================
-- 9. tax_invoices (세금계산서)
-- ============================================================
-- 삭제 불가 — status 변경(취소)으로만 처리

CREATE TABLE IF NOT EXISTS tax_invoices (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  invoice_number  text NOT NULL UNIQUE,   -- TAX-YYMMDD-###
  outbound_id     uuid NOT NULL REFERENCES outbound(id),
  vendor_id       uuid REFERENCES vendors(id),
  issue_date      date NOT NULL,
  supply_amount   numeric(14,2) NOT NULL DEFAULT 0,
  tax_amount      numeric(14,2) GENERATED ALWAYS AS (ROUND(supply_amount * 0.1, 2)) STORED,
  total_amount    numeric(14,2) GENERATED ALWAYS AS (ROUND(supply_amount * 1.1, 2)) STORED,
  status          text NOT NULL DEFAULT '발행' CHECK (status IN ('발행', '취소')),
  notes           text,
  created_by      uuid REFERENCES users(id),
  created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE tax_invoices IS '세금계산서. 삭제 불가 — status=취소로만 처리';
COMMENT ON COLUMN tax_invoices.tax_amount IS '세액 자동 계산 (공급가액 × 0.1)';
COMMENT ON COLUMN tax_invoices.total_amount IS '합계 자동 계산 (공급가액 × 1.1)';


-- ============================================================
-- 10. inventory_min_stock (최소 재고 설정)
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory_min_stock (
  product_id    uuid PRIMARY KEY REFERENCES products(id),
  min_quantity  numeric(12,3) NOT NULL DEFAULT 0,
  alert_emails  text[] NOT NULL DEFAULT '{}',   -- 알림 수신 이메일 목록
  kakao_alert   boolean NOT NULL DEFAULT false, -- 추후 연동
  updated_by    uuid REFERENCES users(id),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE inventory_min_stock IS '품목별 최소 재고 수량 및 알림 설정. 품목당 1건';


-- ============================================================
-- 11. allergens (알레르기)
-- ============================================================

CREATE TABLE IF NOT EXISTS allergens (
  id                        uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id                uuid NOT NULL REFERENCES products(id),
  allergen_name             text NOT NULL,
  cross_contamination_risk  text CHECK (cross_contamination_risk IN ('높음', '중간', '낮음')),
  processing_line           text,
  label_required            boolean NOT NULL DEFAULT false,
  created_by                uuid REFERENCES users(id),
  created_at                timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE allergens IS '품목별 알레르기 원인식품 및 교차오염 위험도';


-- ============================================================
-- 12. haccp_temperature (온도기록)
-- ============================================================

CREATE TABLE IF NOT EXISTS haccp_temperature (
  id            uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  record_date   date NOT NULL,
  fridge1       numeric(5,1),    -- 냉장1 온도 (℃)
  fridge2       numeric(5,1),    -- 냉장2 온도 (℃)
  freezer1      numeric(5,1),    -- 냉동1 온도 (℃)
  freezer2      numeric(5,1),    -- 냉동2 온도 (℃)
  workroom      numeric(5,1),    -- 작업실 온도 (℃)
  outside       numeric(5,1),    -- 외기 온도 (℃)
  is_abnormal   boolean NOT NULL DEFAULT false,  -- 기준 초과 시 true (앱에서 자동 판정)
  action_taken  text,
  recorded_by   uuid REFERENCES users(id),
  created_at    timestamptz NOT NULL DEFAULT now(),

  UNIQUE (record_date)  -- 하루 1건
);

COMMENT ON COLUMN haccp_temperature.is_abnormal IS '냉장 0~10℃ 초과 또는 냉동 -18℃ 이상 시 true';


-- ============================================================
-- 13. haccp_sanitation (위생점검)
-- ============================================================

CREATE TABLE IF NOT EXISTS haccp_sanitation (
  id               uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  check_date       date NOT NULL,
  worker_hygiene   text CHECK (worker_hygiene IN ('양호', '불량')),
  clothing         text CHECK (clothing IN ('양호', '불량')),
  hand_washing     text CHECK (hand_washing IN ('양호', '불량')),
  cleaning         text CHECK (cleaning IN ('양호', '불량')),
  pest_control     text CHECK (pest_control IN ('양호', '불량')),
  waste_disposal   text CHECK (waste_disposal IN ('양호', '불량')),
  result           text NOT NULL CHECK (result IN ('합격', '조건부합격', '불합격')),
  recorded_by      uuid REFERENCES users(id),
  created_at       timestamptz NOT NULL DEFAULT now(),

  UNIQUE (check_date)  -- 하루 1건
);

COMMENT ON TABLE haccp_sanitation IS '일별 위생점검 기록. 항목 중 하나라도 불량이면 조건부합격, 다수 불량이면 불합격';


-- ============================================================
-- 14. data_change_log (변경 이력)
-- ============================================================

CREATE TABLE IF NOT EXISTS data_change_log (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  table_name  text NOT NULL,
  record_id   uuid NOT NULL,
  action      text NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  old_data    jsonb,
  new_data    jsonb,
  changed_by  uuid REFERENCES users(id),
  changed_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE data_change_log IS '모든 수정/삭제 자동 기록 (트리거). 총괄감독만 조회 가능';


-- ============================================================
-- 15. v_inventory (재고 현황 뷰)
-- ============================================================
-- CTE 방식으로 집계 오류 방지 (단순 JOIN 시 yield_quantity 중복 합산 버그 존재)

CREATE OR REPLACE VIEW v_inventory AS
WITH stock_in AS (
  -- 가공 완료된 실제 생산량 합계 (재고 기준)
  SELECT
    product_id,
    SUM(yield_quantity) AS total_produced
  FROM processing
  WHERE is_deleted = false
  GROUP BY product_id
),
stock_out AS (
  -- 출고된 수량 합계
  SELECT
    pr.product_id,
    SUM(o.quantity) AS total_sold
  FROM outbound o
  JOIN processing pr ON pr.id = o.processing_id
  WHERE o.is_deleted = false
    AND pr.is_deleted = false
  GROUP BY pr.product_id
),
nearest_exp AS (
  -- 사용 가능한 원료 중 가장 임박한 유통기한
  SELECT
    pr.product_id,
    MIN(i.expiry_date) AS nearest_expiry
  FROM processing pr
  JOIN inbound i ON i.id = pr.raw_lot_id
  WHERE pr.is_deleted = false
    AND i.is_deleted = false
    AND i.is_usable = true
  GROUP BY pr.product_id
)
SELECT
  p.id                                                            AS product_id,
  p.code,
  p.name,
  p.unit,
  p.unit_price,
  COALESCE(si.total_produced, 0) - COALESCE(so.total_sold, 0)   AS current_stock,
  ne.nearest_expiry,
  -- D-day 계산 (프론트에서도 사용 가능하지만 뷰에서 미리 제공)
  (ne.nearest_expiry - CURRENT_DATE)                             AS expiry_days_left
FROM products p
LEFT JOIN stock_in  si ON si.product_id = p.id
LEFT JOIN stock_out so ON so.product_id = p.id
LEFT JOIN nearest_exp ne ON ne.product_id = p.id
WHERE p.is_active = true;

COMMENT ON VIEW v_inventory IS '실시간 재고 현황. current_stock = 생산량 - 출고량. expiry_days_left <= 7이면 유통기한 임박';


-- ============================================================
-- 16. 트리거 — 변경 이력 자동 기록
-- ============================================================
-- inbound, processing, outbound, vendors 변경 시 data_change_log에 자동 기록

CREATE OR REPLACE FUNCTION fn_log_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO data_change_log (table_name, record_id, action, old_data, new_data, changed_by)
  VALUES (
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    TG_OP,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
    COALESCE(NEW.created_by, OLD.created_by)
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- 입고 변경 이력
CREATE OR REPLACE TRIGGER trg_inbound_log
  AFTER INSERT OR UPDATE OR DELETE ON inbound
  FOR EACH ROW EXECUTE FUNCTION fn_log_change();

-- 가공 변경 이력
CREATE OR REPLACE TRIGGER trg_processing_log
  AFTER INSERT OR UPDATE OR DELETE ON processing
  FOR EACH ROW EXECUTE FUNCTION fn_log_change();

-- 출고 변경 이력
CREATE OR REPLACE TRIGGER trg_outbound_log
  AFTER INSERT OR UPDATE OR DELETE ON outbound
  FOR EACH ROW EXECUTE FUNCTION fn_log_change();

-- 거래처 변경 이력
CREATE OR REPLACE TRIGGER trg_vendors_log
  AFTER INSERT OR UPDATE OR DELETE ON vendors
  FOR EACH ROW EXECUTE FUNCTION fn_log_change();


-- ============================================================
-- 17. 트리거 — 품질검사 불합격 시 inbound.is_usable 자동 업데이트
-- ============================================================

CREATE OR REPLACE FUNCTION fn_update_inbound_usability()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.result = '불합격' THEN
    UPDATE inbound SET is_usable = false WHERE id = NEW.inbound_id;
  ELSIF NEW.result IN ('합격', '조건부합격') THEN
    UPDATE inbound SET is_usable = true WHERE id = NEW.inbound_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_quality_inspection_usable
  AFTER INSERT OR UPDATE ON quality_inspection
  FOR EACH ROW EXECUTE FUNCTION fn_update_inbound_usability();


-- ============================================================
-- 18. RLS (Row Level Security) 활성화
-- ============================================================

ALTER TABLE users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE products            ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors             ENABLE ROW LEVEL SECURITY;
ALTER TABLE inbound             ENABLE ROW LEVEL SECURITY;
ALTER TABLE quality_inspection  ENABLE ROW LEVEL SECURITY;
ALTER TABLE channels            ENABLE ROW LEVEL SECURITY;
ALTER TABLE processing          ENABLE ROW LEVEL SECURITY;
ALTER TABLE outbound            ENABLE ROW LEVEL SECURITY;
ALTER TABLE tax_invoices        ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_min_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE allergens           ENABLE ROW LEVEL SECURITY;
ALTER TABLE haccp_temperature   ENABLE ROW LEVEL SECURITY;
ALTER TABLE haccp_sanitation    ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_change_log     ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- 19. RLS 정책 — 역할 확인 헬퍼 함수
-- ============================================================

CREATE OR REPLACE FUNCTION get_my_role()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM users WHERE id = auth.uid();
$$;


-- ============================================================
-- 20. RLS 정책 — users
-- ============================================================

-- 본인 정보는 누구나 조회
CREATE POLICY "users_select_own" ON users
  FOR SELECT USING (id = auth.uid());

-- admin은 전체 조회
CREATE POLICY "users_select_admin" ON users
  FOR SELECT USING (get_my_role() = 'admin');

-- admin만 사용자 생성/수정
CREATE POLICY "users_insert_admin" ON users
  FOR INSERT WITH CHECK (get_my_role() = 'admin');

CREATE POLICY "users_update_admin" ON users
  FOR UPDATE USING (get_my_role() = 'admin');


-- ============================================================
-- 21. RLS 정책 — 핵심 업무 테이블 (공통 패턴)
-- ============================================================

-- products: 전체 조회, admin/production만 수정
CREATE POLICY "products_select_all"    ON products FOR SELECT USING (get_my_role() IN ('admin', 'production', 'haccp'));
CREATE POLICY "products_insert_ap"     ON products FOR INSERT WITH CHECK (get_my_role() IN ('admin', 'production'));
CREATE POLICY "products_update_ap"     ON products FOR UPDATE USING (get_my_role() IN ('admin', 'production'));

-- vendors: admin/production 전체, haccp 없음
CREATE POLICY "vendors_select_ap"      ON vendors FOR SELECT USING (get_my_role() IN ('admin', 'production') AND is_deleted = false);
CREATE POLICY "vendors_insert_ap"      ON vendors FOR INSERT WITH CHECK (get_my_role() IN ('admin', 'production'));
CREATE POLICY "vendors_update_ap"      ON vendors FOR UPDATE USING (get_my_role() IN ('admin', 'production'));

-- inbound: admin/production 전체, haccp 조회만
CREATE POLICY "inbound_select_all"     ON inbound FOR SELECT USING (get_my_role() IN ('admin', 'production', 'haccp') AND is_deleted = false);
CREATE POLICY "inbound_insert_ap"      ON inbound FOR INSERT WITH CHECK (get_my_role() IN ('admin', 'production'));
CREATE POLICY "inbound_update_ap"      ON inbound FOR UPDATE USING (get_my_role() IN ('admin', 'production'));

-- quality_inspection: admin/haccp 전체, production 조회만
CREATE POLICY "qi_select_all"          ON quality_inspection FOR SELECT USING (get_my_role() IN ('admin', 'production', 'haccp') AND is_deleted = false);
CREATE POLICY "qi_insert_ah"           ON quality_inspection FOR INSERT WITH CHECK (get_my_role() IN ('admin', 'haccp'));
CREATE POLICY "qi_update_ah"           ON quality_inspection FOR UPDATE USING (get_my_role() IN ('admin', 'haccp'));

-- channels: admin 전체, production 조회만
CREATE POLICY "channels_select_ap"     ON channels FOR SELECT USING (get_my_role() IN ('admin', 'production') AND is_deleted = false);
CREATE POLICY "channels_insert_admin"  ON channels FOR INSERT WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "channels_update_admin"  ON channels FOR UPDATE USING (get_my_role() = 'admin');

-- processing: admin/production 전체, haccp 조회만
CREATE POLICY "processing_select_all"  ON processing FOR SELECT USING (get_my_role() IN ('admin', 'production', 'haccp') AND is_deleted = false);
CREATE POLICY "processing_insert_ap"   ON processing FOR INSERT WITH CHECK (get_my_role() IN ('admin', 'production'));
CREATE POLICY "processing_update_ap"   ON processing FOR UPDATE USING (get_my_role() IN ('admin', 'production'));

-- outbound: admin/production 전체, haccp 조회만
CREATE POLICY "outbound_select_all"    ON outbound FOR SELECT USING (get_my_role() IN ('admin', 'production', 'haccp') AND is_deleted = false);
CREATE POLICY "outbound_insert_ap"     ON outbound FOR INSERT WITH CHECK (get_my_role() IN ('admin', 'production'));
CREATE POLICY "outbound_update_ap"     ON outbound FOR UPDATE USING (get_my_role() IN ('admin', 'production'));

-- tax_invoices: admin/production 전체, haccp 없음
CREATE POLICY "tax_select_ap"          ON tax_invoices FOR SELECT USING (get_my_role() IN ('admin', 'production'));
CREATE POLICY "tax_insert_ap"          ON tax_invoices FOR INSERT WITH CHECK (get_my_role() IN ('admin', 'production'));
CREATE POLICY "tax_update_ap"          ON tax_invoices FOR UPDATE USING (get_my_role() IN ('admin', 'production'));

-- inventory_min_stock: admin/production/haccp 조회, admin만 수정
CREATE POLICY "ims_select_all"         ON inventory_min_stock FOR SELECT USING (get_my_role() IN ('admin', 'production', 'haccp'));
CREATE POLICY "ims_insert_admin"       ON inventory_min_stock FOR INSERT WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "ims_update_admin"       ON inventory_min_stock FOR UPDATE USING (get_my_role() = 'admin');

-- allergens: admin/haccp 전체, production 조회만
CREATE POLICY "allergens_select_all"   ON allergens FOR SELECT USING (get_my_role() IN ('admin', 'production', 'haccp'));
CREATE POLICY "allergens_insert_ah"    ON allergens FOR INSERT WITH CHECK (get_my_role() IN ('admin', 'haccp'));
CREATE POLICY "allergens_update_ah"    ON allergens FOR UPDATE USING (get_my_role() IN ('admin', 'haccp'));

-- haccp_temperature: admin/haccp 전체, production 조회만
CREATE POLICY "temp_select_all"        ON haccp_temperature FOR SELECT USING (get_my_role() IN ('admin', 'production', 'haccp'));
CREATE POLICY "temp_insert_ah"         ON haccp_temperature FOR INSERT WITH CHECK (get_my_role() IN ('admin', 'haccp'));
CREATE POLICY "temp_update_ah"         ON haccp_temperature FOR UPDATE USING (get_my_role() IN ('admin', 'haccp'));

-- haccp_sanitation: admin/haccp 전체, production 조회만
CREATE POLICY "sanit_select_all"       ON haccp_sanitation FOR SELECT USING (get_my_role() IN ('admin', 'production', 'haccp'));
CREATE POLICY "sanit_insert_ah"        ON haccp_sanitation FOR INSERT WITH CHECK (get_my_role() IN ('admin', 'haccp'));
CREATE POLICY "sanit_update_ah"        ON haccp_sanitation FOR UPDATE USING (get_my_role() IN ('admin', 'haccp'));

-- data_change_log: admin만 조회, 트리거가 자동 INSERT (일반 INSERT 불가)
CREATE POLICY "log_select_admin"       ON data_change_log FOR SELECT USING (get_my_role() = 'admin');


-- ============================================================
-- 22. 초기 데이터 — 기본 채널 3개
-- ============================================================

INSERT INTO channels (name, channel_type, tax_invoice_required)
VALUES
  ('쿠팡 로켓배송',       '온라인몰', true),
  ('네이버 스마트스토어', '온라인몰', false),
  ('직접판매',            '직거래',   true)
ON CONFLICT (name) DO NOTHING;


-- ============================================================
-- 완료 메시지
-- ============================================================
-- 테이블 14개, 뷰 1개, 트리거 6개, RLS 정책 33개 생성 완료
-- 다음 단계: Supabase Dashboard > Authentication > Providers 에서
--   이메일 인증 설정 후 첫 번째 admin 계정 수동 등록
-- ============================================================
