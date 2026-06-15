# 서해수산 가공㈜ 업무 자동화 시스템 PRD v1.1

**Product Requirements Document**  
작성일: 2026년 6월 15일 | 작성자: KACCA 한국AI창의융합협회  
플랫폼: Supabase + Next.js + Vercel | 참고: 동해수산 PRD v2.0 기반

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

> `=` v1.1에서 추가/변경된 항목

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
| 프론트엔드 | Next.js + Tailwind CSS | 화면 구성 (코워크에서 개발) |
| 백엔드/DB | Supabase (PostgreSQL) | 데이터 저장, 실시간 구독 |
| 인증 | Supabase Auth | 이메일/비밀번호 로그인, 역할 관리 |
| 파일 저장 | Supabase Storage | PDF, 첨부파일 저장 |
| 배포 | Vercel | GitHub 연동 자동 배포 |
| PDF 출력 | 브라우저 인쇄 | 세금계산서, HACCP 문서 |

### 2-2. 개발 파이프라인

```
코워크(Claude AI) → 로컬 폴더 저장 → GitHub Push → Vercel 자동 배포
```

### 2-3. 파일 구조 (Next.js)

```
seohae-erp/
├── app/
│   ├── (auth)/login/       # 로그인
│   ├── dashboard/          # 대시보드
│   ├── inbound/            # 입고 관리
│   ├── processing/         # 가공 관리
│   ├── outbound/           # 출고 관리
│   ├── inventory/          # 재고 현황
│   ├── haccp/              # HACCP
│   ├── allergen/           # 알레르기 관리
│   ├── tax-invoice/        # 세금계산서
│   ├── vendor/             # 거래처 관리
│   ├── channels/           # 출고 채널 관리 ✨
│   ├── report/             # 보고서
│   └── admin/users/        # 사용자 관리
├── components/
├── lib/supabase.ts
└── middleware.ts
```

---

## 3장. 사용자 역할 및 권한

### 3-1. 역할 정의

| 역할 | 설명 | 접근 가능 메뉴 |
|------|------|----------------|
| 총괄감독 (admin) | 모든 기능 접근, 사용자 관리 | 전체 |
| 생산부장 (production) | 입출고·가공·재고·이력 관리 | 대시보드, 입고, 가공, 출고, 재고, 이력, 거래처, 세금계산서, 채널, 보고서 |
| HACCP담당자 (haccp) | HACCP 문서·점검·출력 | 대시보드, HACCP, 알레르기, 이력, 보고서 |

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

1. 로그인 요청
2. Supabase Auth 검증
3. 사용자 역할(role) 조회
4. 역할별 대시보드로 리다이렉트
5. middleware.ts에서 페이지 접근 시마다 권한 체크
6. 권한 없는 페이지 → 403 또는 대시보드 리다이렉트

### 4-3. 보안 설정

- Supabase Auth 기반 JWT 세션 관리
- 세션 만료: 8시간 (근무시간 기준)
- RLS로 역할별 데이터 접근 제어
- 본인이 등록한 데이터만 수정 가능 (총괄감독 제외)

---

## 5장. 로트번호 체계

동해수산 PRD v2.0과 동일한 체계 유지

| 종류 | 형식 | 예시 | 생성 위치 |
|------|------|------|-----------|
| 원료 입고 로트 | YYMMDD-M##-## | 260530-M01-01 | 입고 등록 시 자동 생성 |
| 가공 로트 | 원료로트-P | 260530-M01-01-P | 가공 등록 시 자동 생성 |
| 출고 번호 | OUT-YYMMDD-### | OUT-260530-001 | 출고 등록 시 자동 생성 |
| 세금계산서 번호 | TAX-YYMMDD-### | TAX-260530-001 | 세금계산서 발행 시 자동 생성 |

---

## 6장. DB 테이블 구성 (Supabase)

### 6-1. users (사용자)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | Supabase Auth UID |
| email | text | 로그인 이메일 |
| name | text | 이름 |
| role | text | admin / production / haccp |
| is_active | boolean | 활성 여부 |
| created_at | timestamp | 생성일시 |

### 6-2. products (품목관리)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| code | text | 제품코드 (M01 등) |
| name | text | 품목명 |
| unit | text | 단위 |
| unit_price | numeric | 단가 |
| is_active | boolean | 활성 여부 |

### 6-3. inbound (입고기록) ✨ expiry_date 추가

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| lot_number | text | 로트번호 (자동생성) |
| inbound_date | date | 입고일자 |
| product_id | uuid | FK → products |
| quantity | numeric | 수량 |
| supplier | text | 공급업체 |
| origin | text | 원산지 |
| **expiry_date** | **date** | **유통기한 — 신규 추가** |
| created_by | uuid | FK → users |
| is_deleted | boolean | 소프트 삭제 |

### 6-4. quality_inspection (품질/관능검사) ✨ 신규 테이블

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| inbound_id | uuid | FK → inbound |
| inspector | uuid | FK → users (검사자) |
| inspection_date | date | 검사일자 |
| appearance | text | 외관 상태 (정상/불량) |
| smell | text | 냄새 (정상/이취) |
| temperature | numeric | 입고 온도 (℃) |
| result | text | 합격/조건부합격/불합격 |
| notes | text | 특이사항 |

### 6-5. channels (출고 채널) ✨ 신규 테이블

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| name | text | 채널명 (예: 쿠팡 로켓배송, 네이버 스마트스토어) |
| channel_type | text | 채널 유형 (온라인몰/직거래/도매) |
| tax_invoice_required | boolean | 세금계산서 자동 발행 여부 |
| default_vendor_id | uuid | FK → vendors (기본 거래처) |
| is_active | boolean | 활성 여부 |

### 6-6. processing (가공기록)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| lot_number | text | 가공로트 (자동생성) |
| process_date | date | 가공일자 |
| product_id | uuid | FK → products |
| quantity | numeric | 가공수량 |
| raw_lot_id | uuid | FK → inbound (원료로트) |
| temperature | numeric | 가공온도 |
| created_by | uuid | FK → users |
| is_deleted | boolean | 소프트 삭제 |

### 6-7. outbound (출고기록) ✨ channel_id 추가

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| out_number | text | 출고번호 (자동생성) |
| outbound_date | date | 출고일자 |
| processing_id | uuid | FK → processing |
| quantity | numeric | 출고수량 |
| vendor_id | uuid | FK → vendors |
| **channel_id** | **uuid** | **FK → channels — 신규 추가** |
| invoice_number | text | 송장번호 |
| is_deleted | boolean | 소프트 삭제 |

### 6-8. inventory_min_stock (최소 재고 설정) ✨ 신규 테이블

| 컬럼 | 타입 | 설명 |
|------|------|------|
| product_id | uuid | FK → products (PK) |
| min_quantity | numeric | 최소 재고 수량 |
| alert_emails | text[] | 알림 수신 이메일 목록 |
| kakao_alert | boolean | 카카오톡 알림 여부 (추후 연동) |
| updated_by | uuid | FK → users |
| updated_at | timestamp | 마지막 수정일시 |

### 6-9. allergens (알레르기)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| product_id | uuid | FK → products |
| allergen_name | text | 알레르기 원인식품 |
| cross_contamination_risk | text | 교차오염 위험도 (높음/중간/낮음) |
| processing_line | text | 가공 라인 |
| label_required | boolean | 표시 의무 여부 |

### 6-10. haccp_temperature (온도기록)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| record_date | date | 기록일자 |
| fridge1 / fridge2 | numeric | 냉장1/2 온도 |
| freezer1 / freezer2 | numeric | 냉동1/2 온도 |
| workroom / outside | numeric | 작업실 / 외기 온도 |
| is_abnormal | boolean | 이상 여부 (자동 판정) |
| action_taken | text | 조치내용 |

### 6-11. haccp_sanitation (위생점검)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| check_date | date | 점검일자 |
| worker_hygiene / clothing | text | 작업자 위생 / 복장 |
| hand_washing / cleaning | text | 손세척 / 청소 |
| pest_control / waste_disposal | text | 해충방제 / 폐기물 |
| result | text | 합격/조건부합격/불합격 (자동 판정) |

### 6-12. data_change_log (변경 이력)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid | PK |
| table_name | text | 변경된 테이블 |
| record_id | uuid | 변경된 레코드 ID |
| action | text | INSERT / UPDATE / DELETE |
| old_data | jsonb | 변경 전 데이터 |
| new_data | jsonb | 변경 후 데이터 |
| changed_by | uuid | FK → users |
| changed_at | timestamp | 변경일시 |

---

## 7장. 화면 구성

| 페이지 | 경로 | 접근 역할 |
|--------|------|-----------|
| 로그인 | /login | 전체 (비인증) |
| 대시보드 | /dashboard | 전체 |
| 입고 관리 | /inbound | admin, production |
| 가공 관리 | /processing | admin, production |
| 출고 관리 | /outbound | admin, production |
| 재고 현황 | /inventory | admin, production |
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

동해수산 PRD v2.0의 입고/가공/출고/재고/이력/세금계산서/거래처 기능과 동일하게 유지.  
아래는 서해수산에서 추가/변경되는 사항만 기술.

### 8-1. 대시보드 추가 항목

- 로그인한 사용자 이름 + 역할 표시 (예: 홍길동 | 생산부장)
- 역할에 따라 보이는 위젯 다름 (생산부장: 재고/입출고 / HACCP담당: 온도/위생)
- 오늘 미완료 HACCP 항목 빨간 배지 표시
- 재고 부족 품목 경고 배지 표시 ✨

### 8-2. 입고 품질/관능검사 ✨ 신규 기능

- 입고 등록 완료 후 품질/관능검사 결과 입력 (별도 폼)
- 검사 항목: 외관, 냄새, 입고 온도, 종합 판정 (합격/조건부합격/불합격)
- 불합격 시 해당 입고 로트 사용 불가 처리
- HACCP 심사 시 품질검사 대장 PDF 출력 가능

### 8-3. 유통기한 관리 ✨ 신규 기능

- 입고 등록 시 유통기한(expiry_date) 필수 입력
- 재고 현황 화면에서 유통기한 임박 품목 강조 표시 (D-7: 노란색, D-3: 빨간색)
- 유통기한 초과 로트는 출고 불가 처리

### 8-4. 출고 채널 관리 ✨ 신규 기능

- admin이 채널 추가/수정/삭제 가능 (/channels 페이지)
- 채널 속성: 채널명, 유형(온라인몰/직거래/도매), 세금계산서 자동 발행 여부, 기본 거래처
- 출고 등록 시 채널 선택 → 세금계산서 발행 시 채널 정보 자동 연결
- 채널별 출고 현황 및 매출 조회 가능 (보고서 페이지)
- 기본 제공 채널: 쿠팡 로켓배송, 네이버 스마트스토어, 직접판매

### 8-5. 재고 부족 알림 ✨ 신규 기능

- 품목별 최소 재고 수량 설정 (admin, /inventory 페이지 내 설정)
- 재고가 최소 수량 이하로 떨어지면 이메일 알림 발송
- 대시보드에 재고 부족 품목 배지 표시
- 카카오톡 알림 연동은 추후 확장 (현재는 이메일)

### 8-6. 입고 수정/삭제 규칙

- 해당 입고 로트로 가공된 기록이 있으면 삭제 불가
- 수정 시 변경 전/후 데이터 data_change_log에 자동 기록
- 삭제는 is_deleted = true 처리 (소프트 삭제)

### 8-7. 가공 수정/삭제 규칙

- 해당 가공 로트로 출고된 기록이 있으면 삭제 불가
- 수정/삭제 시 변경 이력 자동 기록

### 8-8. 출고 수정/삭제 규칙

- 세금계산서가 발행된 출고는 삭제 불가
- 수정/삭제 시 변경 이력 자동 기록

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
- 포함 항목: 온도기록 / 위생점검 / 입고 현황 / 품질검사 기록 ✨ / 알레르기 관리 대장 / 이력추적
- 선택 항목 한 번에 PDF 출력 (브라우저 인쇄)

### 10-2. 자동 알림 ✨ 카카오톡 채널 추가 검토

| 알림 조건 | 이메일 | 카카오톡 | 시점 |
|-----------|--------|----------|------|
| 오늘 온도기록 미입력 | ✅ | 검토 중 | 매일 오전 8시 |
| 오늘 위생점검 미완료 | ✅ | 검토 중 | 매일 오전 8시 |
| 냉장 0~10℃ 초과 | 화면 경고 | - | 입력 즉시 |
| 냉동 -18℃ 이상 | 화면 경고 | - | 입력 즉시 |
| 재고 부족 | ✅ | 검토 중 | 재고 변동 시 |

> 카카오톡 알림: v1에서 이메일 우선 구현, 단기 확장 계획으로 이동

### 10-3. 월간 보고서 자동화

- 매월 1일 전월 보고서 자동 생성 → Supabase Storage 저장
- 보고서 다운로드 페이지에서 월별 이력 조회
- 포함 항목: 월간 요약 / 입고 현황 / 가공 현황 / 출고 현황(채널별) ✨ / 온도기록 / 위생점검

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

### 11-2. 소프트 삭제

- 모든 삭제는 is_deleted = true 처리 (실제 데이터 보존)
- 화면에서는 삭제된 것처럼 보이지 않음
- 총괄감독은 삭제 이력 조회 가능

### 11-3. 변경 이력 관리

- 모든 수정/삭제 시 data_change_log 자동 기록 (Supabase DB 트리거)
- 총괄감독 전용 변경 이력 조회 페이지
- 변경 전/후 데이터 JSON 형태로 보존

### 11-4. Supabase RLS 정책

- 역할별 SELECT / INSERT / UPDATE / DELETE 권한 분리
- 소프트 삭제된 데이터는 일반 조회에서 자동 필터링
- 본인이 등록한 데이터만 수정 가능 (총괄감독 제외)

---

## 12장. 비기능 요구사항

| 항목 | 요구사항 |
|------|----------|
| 인증 | Supabase Auth 기반 JWT 세션 관리 |
| 보안 | RLS로 역할별 데이터 접근 제어 |
| 성능 | 데이터 입력 후 목록 즉시 갱신 (2초 이내) |
| 접근성 | PC 및 스마트폰 반응형 UI |
| 배포 | GitHub Push → Vercel 자동 배포 |
| 백업 | Supabase 자동 백업 (무료 플랜: 7일) |
| 확장성 | company_id 컬럼 예비 설계 (SaaS 전환 대비) |
| 비용 | Supabase 무료 플랜 + Vercel 무료 플랜으로 운영 |

---

## 13장. 향후 확장 계획

### 단기 (3개월 이내)

- 카카오톡 알림 연동 (재고 부족, 온도 이상, HACCP 미완료)
- 바코드 스캔 입력

### 중기 — SaaS 전환

- company_id 기반 멀티테넌트 구조 적용
- 업체별 계정 발급 및 데이터 완전 분리
- 구독 결제 시스템 연동 (Stripe)
- 수산가공업 전용 ERP 플랫폼 출시

### 장기

- 홈택스 세금계산서 자동 전송
- 쿠팡/네이버 스마트스토어 발주 데이터 자동 수신
- 스마트 HACCP 공식 인증 연동

---

*서해수산 가공㈜ 업무 자동화 시스템 PRD v1.1 | KACCA 한국AI창의융합협회 | 2026.06.15*
