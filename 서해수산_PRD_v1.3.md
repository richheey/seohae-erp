# 서해수산 가공㈜ 업무 자동화 시스템 PRD v1.3

**Product Requirements Document**  
작성일: 2026년 6월 15일 | 최종수정: 2026년 6월 16일 | 작성자: KACCA 한국AI창의융합협회  
플랫폼: Supabase + Next.js + Vercel (전 플랜 무료)

> **버전 이력**
>
> | 버전 | 주요 변경 |
> |------|-----------|
> | v1.0 | 최초 작성 |
> | v1.1 | quality_inspection, channels, inventory_min_stock 테이블 추가, expiry_date/channel_id 추가 |
> | v1.2 | vendors/tax_invoices 테이블 추가, 권한 불일치 수정, DB 컬럼 일관성 정비, 8장 기능 상세 추가 |
> | v1.3 | v_inventory SQL 버그 수정, inbound.is_usable 추가, channels.is_deleted 추가, tax_invoices.is_deleted 제거, outbound 컬럼명 명확화, haccp_sanitation 컬럼 분리, 파일구조 수정, Supabase 무료플랜 주의사항 추가, 월간보고서 단순화 |

> `✨` v1.1에서 추가/변경  
> `🔧` v1.2에서 수정/보완  
> `🛠` v1.3에서 수정/보완

---

## 목차

1. 프로젝트 개요 및 배경
2. 시스템 아키텍처
3. 사용자 역할 및 권한
4. 로그인 & 인증
5. 로트번호 체계
6. DB 테이블 구성 (Supabase)
7. 화면 구성
8. 기능 상세 요구사항
9. 알레르기 관리
10. HACCP 자동화
11. 데이터 무결성
12. 비기능 요구사항
13. 향후 확장 계획

---

## 1장. 프로젝트 개요 및 배경

### 1-1. 배경

- 동해수산 앱(Apps Script 기반)의 기능을 검증 완료
- 역할별 접근 제어, 알레르기 관리, 데이터 무결성 등 실제 공장 운영 요구사항 반영 필요
- 향후 SaaS 사업화를 위한 확장 가능한 스택으로 전환
- Supabase Row Level Security(RLS)로 데이터 보안 강화

### 1-2. 목표

- 역할별 로그인으로 담당자만 해당 기능 접근
- 알레르기 원인식품 관리 및 교차오염 체크 자동화
- HACCP 심사 대응용 문서 묶음 즉시 출력
- 데이터 삭제/수정 시 무결성 검증 및 이력 자동 기록
- GitHub Push → Vercel 자동 배포 파이프라인

### 1-3. 회사 정보 (가상)

| 항목 | 내용 |
|------|------|
| 회사명 | 서해수산 가공㈜ |
| 업종 | 수산물 가공 (고등어, 오징어, 명태 등) |
| 주요 거래처 | 쿠팡 로켓배송, 네이버 스마트스토어 |
| 직원 수 | 8명 (대표 + 총괄감독 + 생산부장 + HACCP담당 + 현장 4) |
| HACCP 인증 | 완료 |
| 현재 관리 | 동해수산 앱 → 고도화 전환 |

---

## 2장. 시스템 아키텍처

### 2-1. 기술 스택

| 구분 | 기술 | 역할 |
|------|------|------|
| 프론트엔드 | Next.js + Tailwind CSS | 화면 구성 |
| 백엔드/DB | Supabase (PostgreSQL) | 데이터 저장 |
| 인증 | Supabase Auth | 이메일/비밀번호 로그인, 역할 관리 |
| 파일 저장 | Supabase Storage | 첨부파일 저장 |
| 배포 | Vercel (Hobby 무료) | GitHub 연동 자동 배포 |
| 이메일 발송 | Resend (무료: 월 3,000건) | 재고 부족·HACCP 미완료 알림 |
| 스케줄러 | Vercel Cron Jobs (무료: cron당 1일 1회) | 일별 알림, 월별 보고서 |
| PDF 출력 | 브라우저 인쇄 | 세금계산서, HACCP 문서, 보고서 |

### 2-2. 개발 파이프라인

```
코워크(Claude AI) → 로컬 폴더 저장 → GitHub Push → Vercel 자동 배포
```

### 2-3. 파일 구조 (Next.js App Router)

```
seohae-erp/
├── app/
│   ├── (auth)/login/           # 로그인
│   ├── api/
│   │   └── cron/               # Vercel Cron 엔드포인트 🛠
│   │       ├── haccp-reminder/ # 매일 오전 8시 HACCP 미완료 알림
│   │       └── monthly-report/ # 매월 1일 보고서 페이지 갱신
│   ├── dashboard/              # 대시보드
│   ├── inbound/                # 입고 관리
│   ├── processing/             # 가공 관리
│   ├── outbound/               # 출고 관리
│   ├── inventory/              # 재고 현황
│   ├── traceability/           # 이력추적
│   ├── haccp/                  # HACCP
│   ├── allergen/               # 알레르기 관리
│   ├── tax-invoice/            # 세금계산서
│   ├── vendor/                 # 거래처 관리
│   ├── channels/               # 출고 채널 관리 ✨
│   ├── report/                 # 보고서
│   └── admin/users/            # 사용자 관리
├── components/
├── lib/
│   ├── supabase.ts
│   └── resend.ts               # 이메일 유틸
└── middleware.ts
```

---

## 3장. 사용자 역할 및 권한

### 3-1. 역할 정의

| 역할 | 설명 | 접근 가능 메뉴 |
|------|------|----------------|
| 총괄감독 (admin) | 모든 기능 접근, 사용자 관리 | 전체 |
| 생산부장 (production) | 입출고·가공·재고·이력 관리 | 대시보드, 입고, 가공, 출고, 재고, 이력, 거래처, 세금계산서, 채널(조회), 보고서 |
| HACCP담당자 (haccp) | HACCP 문서·점검·출력 | 대시보드, HACCP, 알레르기, 재고(조회), 이력, 보고서 |

### 3-2. 권한 매트릭스

| 기능 | 총괄감독 | 생산부장 | HACCP담당자 |
|------|----------|----------|-------------|
| 대시보드 | ✅ | ✅ | ✅ |
| 입고 관리 | ✅ | ✅ | 조회만 |
| 가공 관리 | ✅ | ✅ | 조회만 |
| 출고 관리 | ✅ | ✅ | 조회만 |
| 재고 현황 | ✅ | ✅ | ✅ |
| 이력추적 | ✅ | ✅ | ✅ |
| HACCP | ✅ | 조회만 | ✅ |
| 알레르기 관리 | ✅ | 조회만 | ✅ |
| 세금계산서 | ✅ | ✅ | - |
| 거래처 관리 | ✅ | ✅ | - |
| 채널 관리 | ✅ | 조회만 | - |
| 보고서 | ✅ | ✅ | ✅ |
| 사용자 관리 | ✅ | - | - |

---

## 4장. 로그인 & 인증

### 4-1. 로그인 화면

- 회사 로고 + '서해수산 가공㈜ 업무 시스템' 타이틀
- 이메일 / 비밀번호 입력
- 로그인 실패 시 에러 메시지 표시
- 비밀번호 찾기 (이메일 발송)

### 4-2. 인증 흐름

1. 로그인 요청 → Supabase Auth 검증
2. `users` 테이블에서 역할(role) 조회
3. 역할별 대시보드로 리다이렉트
4. `middleware.ts`에서 페이지 접근 시마다 권한 체크
5. 권한 없는 페이지 → 대시보드 리다이렉트

### 4-3. 보안 설정

- Supabase Auth 기반 JWT 세션 관리
- 세션 만료: 8시간 (근무시간 기준)
- RLS로 역할별 데이터 접근 제어
- 본인이 등록한 데이터만 수정 가능 (총괄감독 제외)

---

## 5장. 로트번호 체계

| 종류 | 형식 | 예시 | 생성 위치 |
|------|------|------|-----------|
| 원료 입고 로트 | YYMMDD-M##-## | 260530-M01-01 | 입고 등록 시 자동 생성 |
| 가공 로트 | 원료로트-P | 260530-M01-01-P | 가공 등록 시 자동 생성 |
| 출고 번호 | OUT-YYMMDD-### | OUT-260530-001 | 출고 등록 시 자동 생성 |
| 세금계산서 번호 | TAX-YYMMDD-### | TAX-260530-001 | 세금계산서 발행 시 자동 생성 |

> `M##`은 `products.code` 값(M01 등)과 연동하여 자동 생성.  
> `###`은 당일 동일 유형 발급 건수 기준 자동 증가.  
> 동시 등록 시 중복 방지를 위해 Supabase 트랜잭션(`SELECT ... FOR UPDATE`) 사용.

---

## 6장. DB 테이블 구성 (Supabase)

> **공통 원칙**
> - 모든 테이블: `created_at timestamptz default now()`
> - 사용자 생성 테이블: `created_by uuid FK → users`
> - 수정/삭제 가능 테이블: `is_deleted boolean default false`

### 6-1. users (사용자)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | Supabase Auth UID (PK) |
| email | text | 로그인 이메일 |
| name | text | 이름 |
| role | text | admin / production / haccp |
| is_active | boolean | 활성 여부 |
| created_at | timestamptz | 생성일시 |

### 6-2. products (품목관리)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| code | text | 제품코드 (M01 등) |
| name | text | 품목명 |
| unit | text | 단위 |
| unit_price | numeric | 단가 |
| allergen_info | text | 알레르기 유발 식품 요약 🛠 |
| is_active | boolean | 활성 여부 |
| created_at | timestamptz | 생성일시 |

### 6-3. vendors (거래처)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| name | text | 거래처명 |
| business_number | text | 사업자등록번호 |
| representative | text | 대표자명 |
| address | text | 주소 |
| phone | text | 전화번호 |
| email | text | 이메일 (세금계산서 수신) |
| vendor_type | text | 공급업체 / 판매처 / 양방향 |
| is_active | boolean | 활성 여부 |
| is_deleted | boolean | 소프트 삭제 |
| created_by | uuid | FK → users |
| created_at | timestamptz | 생성일시 |

### 6-4. inbound (입고기록)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| lot_number | text | 로트번호 (자동생성) |
| inbound_date | date | 입고일자 |
| product_id | uuid | FK → products |
| quantity | numeric | 입고 수량 |
| vendor_id | uuid | FK → vendors (선택) |
| origin | text | 원산지 |
| expiry_date | date | 유통기한 ✨ |
| is_usable | boolean | 사용 가능 여부 (기본 true, 품질검사 불합격 시 false) 🛠 |
| created_by | uuid | FK → users |
| is_deleted | boolean | 소프트 삭제 |
| created_at | timestamptz | 생성일시 |

### 6-5. quality_inspection (품질/관능검사) ✨

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| inbound_id | uuid | FK → inbound |
| inspector_id | uuid | FK → users (검사 및 입력 담당자) |
| inspection_date | date | 검사일자 |
| appearance | text | 외관 상태 (정상/불량) |
| smell | text | 냄새 (정상/이취) |
| temperature | numeric | 입고 온도 (℃) |
| result | text | 합격/조건부합격/불합격 |
| notes | text | 특이사항 |
| is_deleted | boolean | 소프트 삭제 |
| created_at | timestamptz | 생성일시 |

### 6-6. channels (출고 채널) ✨

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| name | text | 채널명 (예: 쿠팡 로켓배송) |
| channel_type | text | 온라인몰 / 직거래 / 도매 |
| tax_invoice_required | boolean | 세금계산서 발행 여부 |
| default_vendor_id | uuid | FK → vendors (기본 거래처) |
| is_active | boolean | 활성 여부 |
| is_deleted | boolean | 소프트 삭제 🛠 |
| created_by | uuid | FK → users |
| created_at | timestamptz | 생성일시 |

### 6-7. processing (가공기록)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| lot_number | text | 가공로트 (자동생성) |
| process_date | date | 가공일자 |
| product_id | uuid | FK → products (완제품) |
| raw_lot_id | uuid | FK → inbound (원료 입고 로트) |
| input_quantity | numeric | 원료 투입량 |
| yield_quantity | numeric | 실제 생산량 (재고 계산 기준) ✨ |
| temperature | numeric | 가공온도 |
| created_by | uuid | FK → users |
| is_deleted | boolean | 소프트 삭제 |
| created_at | timestamptz | 생성일시 |

### 6-8. outbound (출고기록)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| out_number | text | 출고번호 (자동생성) |
| outbound_date | date | 출고일자 |
| processing_id | uuid | FK → processing |
| quantity | numeric | 출고수량 |
| vendor_id | uuid | FK → vendors |
| channel_id | uuid | FK → channels ✨ |
| delivery_invoice_number | text | 배송 송장번호 (택배사 운송장) 🛠 |
| created_by | uuid | FK → users |
| is_deleted | boolean | 소프트 삭제 |
| created_at | timestamptz | 생성일시 |

### 6-9. tax_invoices (세금계산서)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| invoice_number | text | 세금계산서 번호 (TAX-YYMMDD-###) |
| outbound_id | uuid | FK → outbound |
| vendor_id | uuid | FK → vendors (공급받는 자) |
| issue_date | date | 발행일자 |
| supply_amount | numeric | 공급가액 |
| tax_amount | numeric | 세액 (supply_amount × 0.1) |
| total_amount | numeric | 합계금액 |
| status | text | 발행 / 취소 (삭제 불가, 상태 변경만) 🛠 |
| notes | text | 비고 |
| created_by | uuid | FK → users |
| created_at | timestamptz | 생성일시 |

### 6-10. inventory_min_stock (최소 재고 설정) ✨

| 컬럼 | 타입 | 설명 |
|------|------|------|
| product_id | uuid | FK → products (PK, 품목당 1건) |
| min_quantity | numeric | 최소 재고 수량 |
| alert_emails | text[] | 알림 수신 이메일 목록 |
| kakao_alert | boolean | 카카오톡 알림 (추후 연동) |
| updated_by | uuid | FK → users |
| updated_at | timestamptz | 마지막 수정일시 |

### 6-11. allergens (알레르기)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| product_id | uuid | FK → products |
| allergen_name | text | 알레르기 원인식품 |
| cross_contamination_risk | text | 교차오염 위험도 (높음/중간/낮음) |
| processing_line | text | 가공 라인 |
| label_required | boolean | 표시 의무 여부 |
| created_by | uuid | FK → users |
| created_at | timestamptz | 생성일시 |

### 6-12. haccp_temperature (온도기록)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| record_date | date | 기록일자 |
| fridge1 | numeric | 냉장1 온도 |
| fridge2 | numeric | 냉장2 온도 |
| freezer1 | numeric | 냉동1 온도 |
| freezer2 | numeric | 냉동2 온도 |
| workroom | numeric | 작업실 온도 |
| outside | numeric | 외기 온도 |
| is_abnormal | boolean | 이상 여부 (자동 판정) |
| action_taken | text | 조치내용 |
| recorded_by | uuid | FK → users |
| created_at | timestamptz | 생성일시 |

### 6-13. haccp_sanitation (위생점검)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| check_date | date | 점검일자 |
| worker_hygiene | text | 작업자 위생 (양호/불량) 🛠 |
| clothing | text | 복장 상태 (양호/불량) 🛠 |
| hand_washing | text | 손세척 (양호/불량) 🛠 |
| cleaning | text | 청소 상태 (양호/불량) 🛠 |
| pest_control | text | 해충방제 (양호/불량) 🛠 |
| waste_disposal | text | 폐기물 처리 (양호/불량) 🛠 |
| result | text | 합격/조건부합격/불합격 (자동 판정) |
| recorded_by | uuid | FK → users |
| created_at | timestamptz | 생성일시 |

### 6-14. data_change_log (변경 이력)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| table_name | text | 변경된 테이블명 |
| record_id | uuid | 변경된 레코드 ID |
| action | text | INSERT / UPDATE / DELETE |
| old_data | jsonb | 변경 전 데이터 |
| new_data | jsonb | 변경 후 데이터 |
| changed_by | uuid | FK → users |
| changed_at | timestamptz | 변경일시 |

> Supabase PostgreSQL 트리거로 자동 기록. 별도 앱 로직 불필요.

### 6-15. 재고 현황 (Supabase View: v_inventory)

별도 `inventory` 테이블 없이 View로 실시간 집계.

```sql
-- v_inventory (CTE 방식으로 집계 오류 방지) 🛠
CREATE VIEW v_inventory AS
WITH stock_in AS (
  SELECT product_id, SUM(yield_quantity) AS total_produced
  FROM processing
  WHERE is_deleted = false
  GROUP BY product_id
),
stock_out AS (
  SELECT pr.product_id, SUM(o.quantity) AS total_sold
  FROM outbound o
  JOIN processing pr ON pr.id = o.processing_id
  WHERE o.is_deleted = false AND pr.is_deleted = false
  GROUP BY pr.product_id
),
nearest_exp AS (
  SELECT pr.product_id, MIN(i.expiry_date) AS nearest_expiry
  FROM processing pr
  JOIN inbound i ON i.id = pr.raw_lot_id
  WHERE pr.is_deleted = false
    AND i.is_deleted = false
    AND i.is_usable = true
  GROUP BY pr.product_id
)
SELECT
  p.id             AS product_id,
  p.name,
  p.unit,
  COALESCE(si.total_produced, 0) - COALESCE(so.total_sold, 0) AS current_stock,
  ne.nearest_expiry
FROM products p
LEFT JOIN stock_in  si ON si.product_id = p.id
LEFT JOIN stock_out so ON so.product_id = p.id
LEFT JOIN nearest_exp ne ON ne.product_id = p.id
WHERE p.is_active = true;
```

> 유통기한 D-7 / D-3 강조는 프론트에서 `nearest_expiry` 기준으로 처리.

---

## 7장. 화면 구성

| 페이지 | 경로 | 접근 역할 |
|--------|------|-----------|
| 로그인 | /login | 전체 (비인증) |
| 대시보드 | /dashboard | 전체 |
| 입고 관리 | /inbound | admin, production |
| 가공 관리 | /processing | admin, production |
| 출고 관리 | /outbound | admin, production |
| 재고 현황 | /inventory | admin, production, haccp |
| 이력추적 | /traceability | 전체 |
| HACCP | /haccp | admin, haccp |
| 알레르기 관리 | /allergen | admin, haccp |
| 세금계산서 | /tax-invoice | admin, production |
| 거래처 관리 | /vendor | admin, production |
| 채널 관리 ✨ | /channels | admin (조회: production) |
| 보고서 | /report | 전체 |
| 사용자 관리 | /admin/users | admin만 |

---

## 8장. 기능 상세 요구사항

### 8-1. 대시보드

| 역할 | 표시 위젯 |
|------|-----------|
| 총괄감독 | 전체 요약 (입고/가공/출고 건수, 재고 부족, HACCP 미완료) |
| 생산부장 | 오늘 입고 현황, 재고 부족 알림 배지, 금주 출고 현황 |
| HACCP담당자 | 오늘 온도기록 여부, 위생점검 여부, 미완료 항목 빨간 배지 |

### 8-2. 입고 관리

- 목록 조회 (검색: 품목명, 로트번호, 공급업체, 기간)
- 등록: 품목 선택 → 수량/거래처/원산지/유통기한 입력 → 로트번호 자동 생성
- 등록 완료 후 품질/관능검사 폼 연동 ✨
- 수정: 가공 기록 없는 경우만 가능, 변경 이력 자동 기록
- 삭제: 가공 기록 있으면 불가, 소프트 삭제
- 유통기한 임박 강조 (D-7: 노란색, D-3: 빨간색) ✨

### 8-3. 입고 품질/관능검사 ✨

- 입고 등록 완료 후 별도 폼으로 검사 결과 입력
- 검사 항목: 외관, 냄새, 입고 온도(℃), 종합 판정(합격/조건부합격/불합격)
- 불합격 시 → `inbound.is_usable = false` 업데이트 → 이후 가공 등록 시 해당 로트 선택 불가 🛠
- HACCP 심사 시 품질검사 대장 PDF 출력 가능

### 8-4. 가공 관리

- 목록 조회 (검색: 가공로트, 품목명, 기간)
- 등록: 완제품 선택 → `is_usable = true`인 유효 입고 로트만 표시 → 원료 투입량/실제 생산량 입력 → 가공로트 자동 생성
- 수정: 출고 기록 없는 경우만 가능, 변경 이력 자동 기록
- 삭제: 출고 기록 있으면 불가, 소프트 삭제

### 8-5. 출고 관리

- 목록 조회 (검색: 출고번호, 품목명, 거래처, 채널, 기간)
- 등록: 가공 로트 선택 → 수량/거래처/채널 선택 → 출고번호 자동 생성
- 채널의 `tax_invoice_required = true`이면 출고 등록 시 세금계산서 발행 안내
- 유통기한 초과 로트 선택 불가
- 수정: 세금계산서 없는 경우만 가능, 변경 이력 자동 기록
- 삭제: 세금계산서 발행된 경우 불가, 소프트 삭제

### 8-6. 재고 현황

- `v_inventory` 뷰 기반 실시간 재고 표시
- 최소 재고 설정 대비 부족 품목 경고 표시
- 유통기한 임박 품목 강조 (D-7: 노란색, D-3: 빨간색)
- admin만 품목별 최소 재고 수량 설정 가능

### 8-7. 이력추적

- 로트번호 또는 품목명으로 검색
- 입고 → 가공 → 출고 연결 이력 트리 표시
- 세금계산서 연결 여부 확인 가능

### 8-8. 세금계산서 관리

- 출고 기록과 1:1 연결
- 발행: 출고 목록에서 선택 → 거래처 정보 자동 불러오기 → TAX 번호 자동 생성
- 공급가액/세액/합계 자동 계산 (세액 = 공급가액 × 0.1)
- PDF 출력 (브라우저 인쇄)
- 취소: `status = '취소'` 처리 (삭제 불가, 이력 보존)

### 8-9. 거래처 관리

- 목록 조회 (공급업체/판매처/전체 필터)
- 등록: 사업자등록번호, 대표자명, 주소, 전화번호, 이메일
- 수정/삭제: 출고·세금계산서 연결 건 있으면 삭제 불가, 소프트 삭제

### 8-10. 출고 채널 관리 ✨

- admin이 채널 추가/수정/삭제 (/channels)
- 채널 속성: 채널명, 유형, 세금계산서 자동 발행 여부, 기본 거래처
- 출고 기록이 있는 채널은 삭제 불가
- 초기 데이터: 쿠팡 로켓배송, 네이버 스마트스토어, 직접판매

### 8-11. 재고 부족 알림 ✨

- admin이 품목별 최소 재고 수량 설정 (/inventory 내)
- 출고 등록 API에서 재고가 최소 수량 이하가 되면 Resend로 이메일 발송
- 수신자: `inventory_min_stock.alert_emails`

### 8-12. 유통기한 관리 ✨

- 입고 등록 시 `expiry_date` 필수 입력
- 재고 현황에서 D-7/D-3 강조 표시
- 유통기한 초과 로트는 가공·출고 등록 시 선택 불가

---

## 9장. 알레르기 관리

### 9-1. 배경

- 수산물 가공 시 동일 라인에서 다른 품목 가공 → 교차오염 위험
- 식품표시법상 알레르기 유발 식품 포장지 표시 의무
- HACCP 심사 시 알레르기 관리 대장 필수 제출

### 9-2. 주요 기능

| 기능 | 상세 내용 |
|------|-----------|
| 품목별 알레르기 등록 | 새우, 고등어, 오징어, 명태 등 원인식품 등록 |
| 교차오염 위험도 설정 | 가공 라인별 높음/중간/낮음 설정 |
| 라벨 문구 자동 생성 | "이 제품은 고등어, 오징어를 사용한 시설에서 제조됩니다" |
| 관리 대장 PDF 출력 | HACCP 심사 대응용 알레르기 관리 대장 출력 |

---

## 10장. HACCP 자동화

### 10-1. 심사 대응 모드

- 날짜 범위 선택 → 해당 기간 HACCP 관련 문서 전체 조회
- 포함: 온도기록 / 위생점검 / 입고 현황 / 품질검사 기록 ✨ / 알레르기 관리 대장 / 이력추적
- 한 번에 PDF 출력 (브라우저 인쇄)

### 10-2. 자동 알림

| 알림 조건 | 수단 | 시점 | 구현 방식 |
|-----------|------|------|-----------|
| 오늘 온도기록 미입력 | 이메일 | 매일 오전 8시 | Vercel Cron + Resend |
| 오늘 위생점검 미완료 | 이메일 | 매일 오전 8시 | Vercel Cron + Resend |
| 냉장 0~10℃ 초과 | 화면 경고 | 입력 즉시 | 클라이언트 검사 |
| 냉동 -18℃ 이상 | 화면 경고 | 입력 즉시 | 클라이언트 검사 |
| 재고 부족 | 이메일 | 재고 변동 시 | 출고 등록 API 내 처리 |

> 카카오톡 알림은 v1에서 제외, 단기 확장 계획으로 이동.

### 10-3. 월간 보고서

- /report 페이지에서 월 선택 → 해당 월 데이터 조회 및 브라우저 인쇄 🛠
- 포함: 월간 요약 / 입고 / 가공 / 출고(채널별) ✨ / 온도기록 / 위생점검
- Vercel Cron으로 매월 1일 리포트 페이지 캐시 갱신 (서버사이드 PDF 저장 제거 🛠)

> v1에서는 복잡도를 낮추기 위해 PDF 자동 생성·저장 대신 브라우저 인쇄 방식으로 운영.  
> 향후 고도화 시 Puppeteer 기반 서버사이드 PDF 저장으로 전환 가능.

---

## 11장. 데이터 무결성

### 11-1. 삭제 방지 규칙

| 데이터 | 삭제 불가 조건 |
|--------|----------------|
| 입고 기록 | 연결된 가공 기록이 있는 경우 |
| 가공 기록 | 연결된 출고 기록이 있는 경우 |
| 출고 기록 | 연결된 세금계산서가 있는 경우 |
| 품목 | 입고/가공/출고 기록에 사용된 경우 |
| 거래처 | 출고/세금계산서에 사용된 경우 |
| 채널 ✨ | 출고 기록에 연결된 경우 |
| 세금계산서 | 항상 삭제 불가 — status '취소'로만 처리 🛠 |

### 11-2. 소프트 삭제

- 삭제 시 `is_deleted = true` 처리 (데이터 보존)
- 일반 조회에서는 `is_deleted = false`만 표시
- 총괄감독은 삭제 이력 조회 가능

### 11-3. 변경 이력 관리

- 수정/삭제 시 `data_change_log` 자동 기록 (PostgreSQL 트리거)
- 총괄감독 전용 변경 이력 조회 페이지
- 변경 전/후 데이터 JSON 보존

### 11-4. Supabase RLS 정책

- 역할별 SELECT / INSERT / UPDATE / DELETE 권한 분리
- `is_deleted = true` 데이터는 일반 조회에서 자동 필터링
- 본인이 등록한 데이터만 수정 가능 (총괄감독 제외)

---

## 12장. 비기능 요구사항

| 항목 | 요구사항 |
|------|----------|
| 인증 | Supabase Auth JWT, 세션 8시간 |
| 보안 | RLS 역할별 접근 제어 |
| 성능 | 데이터 입력 후 목록 갱신 2초 이내 |
| 접근성 | PC 및 스마트폰 반응형 UI |
| 배포 | GitHub Push → Vercel 자동 배포 |
| 백업 | Supabase 자동 백업 (무료: 최근 7일) |
| 이메일 | Resend 무료 (월 3,000건 이내) |
| 스케줄러 | Vercel Cron Jobs 무료 (cron 엔드포인트당 최소 1일 1회) |
| 확장성 | 주요 테이블에 `company_id uuid` 예비 컬럼 추가 예정 |
| 비용 | 전 플랜 무료 운영 (Supabase + Vercel + Resend) |

> **`company_id` 예비 컬럼 적용 대상** (SaaS 전환 시 추가):  
> `users`, `products`, `vendors`, `inbound`, `processing`, `outbound`, `tax_invoices`, `channels`, `allergens`, `inventory_min_stock`

> ⚠️ **Supabase 무료 플랜 주의사항** 🛠  
> 7일 이상 아무 요청이 없으면 프로젝트가 자동 일시정지됨.  
> Vercel Cron의 매일 HACCP 알림 요청이 활동으로 인식되어 정지 방지에 도움됨.  
> 장기 휴무 기간(추석, 설 연휴 등)에는 수동으로 Supabase 대시보드에 접속하여 정지 방지 필요.

---

## 13장. 향후 확장 계획

### 단기 (3개월 이내)

- 카카오톡 알림 연동 (재고 부족, 온도 이상, HACCP 미완료)
- 바코드 스캔 입력
- 월간 보고서 서버사이드 PDF 자동 저장 (Puppeteer)

### 중기 — SaaS 전환

- `company_id` 기반 멀티테넌트 구조 적용
- 업체별 계정 발급 및 데이터 완전 분리
- 구독 결제 시스템 연동 (Stripe)

### 장기

- 홈택스 세금계산서 자동 전송
- 쿠팡/네이버 발주 데이터 자동 수신
- 스마트 HACCP 공식 인증 연동

---

*서해수산 가공㈜ 업무 자동화 시스템 PRD v1.3 | KACCA 한국AI창의융합협회 | 2026.06.16*
