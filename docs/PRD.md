[CX_Community_PRD.md](https://github.com/user-attachments/files/26890118/CX_Community_PRD.md)
# CX Lab — 제품 요구사항 문서 (PRD)

> 버전: v0.1 | 작성일: 2026-04-20 | 상태: 초안

---

## 1. 프로젝트 개요

### 1.1 배경

CX(고객경험) / CSM(고객성공) / CRM 업무를 수행하는 실무자를 위한 전용 커뮤니티가 국내에 부재한 상황이다. 해당 직군의 실무 경험자가 직접 운영하는 커뮤니티를 구축하여, 양질의 정보 큐레이션과 실무자 간 교류의 장을 제공한다.

### 1.2 핵심 목표

| 목표 | 설명 |
|---|---|
| 정보 제공 | CX/CSM/CRM 관련 뉴스를 자동 수집·큐레이션하여 실무자에게 제공 |
| 커뮤니티 형성 | 실무자 간 경험·노하우 교류가 가능한 게시판 운영 |
| 데이터 축적 | 게시글·반응 데이터를 기반으로 직군 인사이트 도출 |
| 비즈니스 확장 | 회원 기반을 확보하여 추후 유료 서비스·B2B 리드로 전환 |

### 1.3 타깃 사용자

- CS팀 / 고객성공팀 / CRM 담당자
- 경력 1~10년 B2B SaaS 또는 이커머스 업종 종사자
- 업계 트렌드에 관심 있는 마케터·기획자 포함

---

## 2. 기술 스택

| 영역 | 도구 | 비고 |
|---|---|---|
| 자동화 | n8n (셀프호스팅 v1.123.18+) | 뉴스 수집·필터링 파이프라인 |
| AI 필터링 | Claude API (Haiku 모델) | 관련성 판단 + 요약 생성 |
| 데이터베이스 | Supabase | 기사·게시글·회원 데이터 통합 관리 |
| 프론트엔드 | Lovable | UI 구현 (Supabase 공식 연동) |
| 뉴스 소스 | Google News RSS | 8개 키워드 기반 수집 |

---

## 3. 정보 구조 (IA)

```
CX Lab
├── 뉴스 피드 (공개)
│   ├── 기사 목록 (카드형)
│   └── 기사 상세
│       └── 에디터 코멘트
│       └── 연결된 토론 스레드
├── 커뮤니티 (로그인 필요)
│   ├── 기사 연결 토론 (article_id 있음)
│   └── 자유 게시판 (article_id null)
└── 아카이브 (공개)
    └── 키워드별 기사 모음
```

### Supabase 테이블 설계

```sql
-- 수집된 기사
articles
  id            uuid PK
  title         text
  url           text
  source        text          -- 언론사명
  keyword       text          -- 수집 키워드
  summary       text          -- Claude 생성 요약
  editor_note   text          -- 운영자 코멘트 (선택)
  score         int           -- Claude 관련성 점수 1-10
  is_published  boolean       -- 홈페이지 노출 여부 (운영자 수동 승인)
  published_at  timestamptz
  created_at    timestamptz

-- 게시글 (토론 + 자유 게시판 통합)
posts
  id            uuid PK
  title         text
  content       text
  author_id     uuid FK → auth.users
  article_id    uuid FK → articles (nullable)
                -- null이면 자유 게시판
                -- 값 있으면 기사 연결 토론
  created_at    timestamptz

-- 댓글
comments
  id            uuid PK
  post_id       uuid FK → posts
  author_id     uuid FK → auth.users
  content       text
  created_at    timestamptz

-- 회원 프로필
profiles
  id            uuid FK → auth.users PK
  nickname      text
  job_title     text          -- 직함 (예: CSM 3년차)
  company_type  text          -- 업종
  created_at    timestamptz
```

---

## 4. 개발 Phase

---

### Phase 1 — 뉴스 자동 수집 파이프라인

> 목표: n8n으로 기사를 자동 수집하고 Supabase에 저장한다.
> 기간 목표: 2~3주

#### 기능 범위

- [ ] n8n Schedule Trigger 설정 (매일 오전 9시)
- [ ] Google News RSS 8개 키워드 수집
  - 고객경험 CX / CS 자동화 / VOC 분석 / CRM 플랫폼
  - 고객 데이터 플랫폼 / 고객 충성도 / AI 고객서비스
  - customer experience trends (영문)
- [ ] XML 파싱 — 제목·링크·날짜·출처 추출
- [ ] Claude API 호출 — 관련성 판단(true/false) + 점수(1-10) + 한 줄 요약
- [ ] Supabase `articles` 테이블에 저장 (`is_published = false` 기본값)
- [ ] 중복 기사 방지 (URL 기준 upsert)

#### n8n 워크플로우 노드 순서

```
Schedule Trigger
  → HTTP Request × 8 (RSS 수집, 병렬)
  → Merge (Append 모드)
  → Code (XML 파싱)
  → HTTP Request (Claude API 호출)
  → Code (응답 파싱)
  → IF (relevant = true)
    → Supabase (Insert/Upsert)
    → [종료]
```

#### Claude 프롬프트 템플릿

```
다음 뉴스 기사가 CX(고객경험), CS(고객서비스), CSM(고객성공),
CRM 업무 담당자에게 실무적으로 유용한지 판단해줘.

제목: {{title}}
출처: {{source}}

JSON만 응답 (다른 텍스트 없이):
{
  "relevant": true 또는 false,
  "score": 1~10,
  "summary": "한 줄 요약 (50자 이내)"
}
```

#### 완료 기준

- 매일 자동 실행 확인
- Supabase articles 테이블에 데이터 쌓이는 것 확인
- 관련 없는 기사(예: 동음이의어 기사)가 필터링되는 것 확인

---

### Phase 2 — 관리자 검토 & 기사 발행

> 목표: 수집된 기사 중 운영자가 선택한 것만 홈페이지에 노출한다.
> 기간 목표: 1~2주

#### 기능 범위

- [ ] Supabase 대시보드에서 `is_published` 토글로 수동 승인
  - (초기에는 별도 관리자 화면 불필요, Supabase Table Editor 활용)
- [ ] 운영자 에디터 코멘트 입력 기능 (`editor_note` 컬럼)
- [ ] (선택) n8n으로 점수 8점 이상 기사는 자동 발행 옵션

#### 완료 기준

- `is_published = true`로 변경한 기사만 프론트에서 조회되는 것 확인

---

### Phase 3 — 뉴스 피드 프론트엔드

> 목표: Lovable로 기사 목록·상세 화면을 구현한다.
> 기간 목표: 2~3주

#### 기능 범위

- [ ] Lovable ↔ Supabase 연동 설정
- [ ] 기사 목록 페이지
  - 카드형 레이아웃
  - 키워드 태그 필터
  - 최신순 정렬
- [ ] 기사 상세 페이지
  - 원문 링크 연결
  - AI 요약 노출
  - 에디터 코멘트 노출 (입력된 경우)
- [ ] 반응형 레이아웃 (모바일 대응)

#### Lovable Supabase 연동 쿼리 예시

```javascript
// 발행된 기사 목록 조회
const { data } = await supabase
  .from('articles')
  .select('*')
  .eq('is_published', true)
  .order('published_at', { ascending: false })
  .limit(20)

// 키워드 필터
.eq('keyword', selectedKeyword)
```

#### 완료 기준

- 기사 목록 화면 정상 렌더링
- 키워드 필터 동작 확인
- 모바일에서 깨지지 않는 것 확인

---

### Phase 4 — 회원 가입 & 커뮤니티 게시판

> 목표: 로그인 기반 게시판을 추가한다. (C안 구조)
> 기간 목표: 3~4주

#### 기능 범위

- [ ] Supabase Auth 기반 회원가입 / 로그인 (이메일)
- [ ] 프로필 설정 (닉네임, 직함, 업종)
- [ ] 자유 게시판 CRUD
- [ ] 기사 연결 토론 스레드
  - 기사 상세 페이지 하단에 "이 기사 토론 보기" 버튼
  - `article_id` 연결된 게시글 목록 표시
- [ ] 댓글 기능
- [ ] 게시글/댓글 작성은 로그인 회원만, 조회는 비회원도 허용

#### 완료 기준

- 회원가입 → 로그인 → 게시글 작성 플로우 정상 동작
- 기사 연결 토론과 자유 게시판 분리 표시 확인
- 비로그인 사용자 게시글 조회 가능 확인

---

### Phase 5 — 데이터 분석 & 확장 (장기)

> 목표: 축적된 데이터를 인사이트로 전환한다.

#### 검토 기능 (우선순위 미정)

- [ ] 뉴스레터 자동 발송 (n8n + 이메일)
- [ ] 인기 키워드 트렌드 대시보드
- [ ] 게시글 주제 클러스터링 (Claude API 활용)
- [ ] 유료 멤버십 또는 기업 대상 리포트 상품화

---

## 5. 비기능 요구사항

| 항목 | 내용 |
|---|---|
| 보안 | Supabase RLS(Row Level Security) 적용 — 본인 게시글만 수정/삭제 가능 |
| 성능 | 기사 목록 초기 로딩 2초 이내 목표 |
| 비용 | Claude Haiku 사용으로 일 40건 기준 월 100원 미만 유지 |
| 확장성 | 키워드 추가 시 n8n 노드만 복제하면 되는 구조 유지 |

---

## 6. 미결정 사항 (Decision Log)

| 항목 | 현황 | 결정 필요 시점 |
|---|---|---|
| 관리자 화면 | Phase 2는 Supabase Table Editor로 대체 | Phase 3 이후 |
| 소셜 로그인 | 이메일 우선, 카카오/구글 추후 검토 | Phase 4 시작 전 |
| 도메인/브랜딩 | 서비스명·도메인 미정 | Phase 3 이전 |
| 뉴스 자동 승인 기준 | 점수 8점 이상 자동 발행 여부 미정 | Phase 2 중 |
| 영문 기사 처리 | 요약만 국문으로 제공할지 원문 그대로 노출할지 미정 | Phase 1 완료 후 |

---

## 7. 진행 체크리스트 요약

### Phase 1 체크리스트
- [ ] n8n Anthropic API Credential 등록
- [ ] n8n Google Sheets / Supabase Credential 등록 (Supabase 사용 시)
- [ ] Supabase 프로젝트 생성 및 테이블 생성
- [ ] n8n 워크플로우 구성 및 테스트 실행
- [ ] 매일 자동 실행 스케줄 활성화

### Phase 3 체크리스트
- [ ] Lovable 프로젝트 생성
- [ ] Supabase 연동 (API Key 설정)
- [ ] 기사 목록 페이지 구현
- [ ] 기사 상세 페이지 구현
- [ ] 배포 및 도메인 연결

---

*이 문서는 개발 진행에 따라 지속적으로 업데이트됩니다.*
