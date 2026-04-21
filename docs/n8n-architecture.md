[n8n-architecture.md](https://github.com/user-attachments/files/26941524/n8n-architecture.md)
# n8n 뉴스 수집 워크플로우 아키텍처

> 버전: v0.1 | 작성일: 2026-04-22 | Phase 1

---

## 1. 개요

CX/CSM/CRM 관련 뉴스를 Google News RSS에서 자동 수집하여 Claude API로 관련성 판단 후, Supabase에 저장하는 파이프라인.

---

## 2. 워크플로우 구조

```
⏰ 매일 9시 실행 (Schedule Trigger)
  │
  ├── RSS 고객경험CX    → Set 고객경험CX       ↘
  ├── RSS CS자동화      → Set CS자동화         ↘
  ├── RSS VOC분석       → Set VOC분석          ↘
  ├── RSS CRM플랫폼     → Set CRM플랫폼        → Merge (append)
  ├── RSS 고객데이터플랫폼 → Set 고객데이터플랫폼 ↗
  ├── RSS 고객충성도    → Set 고객충성도       ↗
  ├── RSS AI고객서비스  → Set AI고객서비스     ↗
  └── RSS CXtrends      → Set CXtrends         ↗
                                                 │
                                                 ▼
                                          XML 파싱 (Code)
                                                 │
                                                 ▼
                                         중복 제거 (Code)
                                                 │
                                                 ▼
                                 Claude 관련성 판단 (HTTP Request)
                                                 │
                                                 ▼
                                     Claude 응답 파싱 (Code)
                                                 │
                                                 ▼
                                       관련 기사 필터 (IF)
                                          ┌──────┴──────┐
                                        true          false
                                          │             │
                                          ▼           (종료)
                                   Supabase 저장
                                    (articles 테이블)
```

---

## 3. 노드별 역할

| 순서 | 노드명 | 타입 | 역할 |
|---|---|---|---|
| 1 | ⏰ 매일 9시 실행 | Schedule Trigger | 매일 정해진 시간 자동 실행 |
| 2-1~8 | RSS × 8 | HTTP Request | Google News RSS에서 키워드별 XML 수집 |
| 3-1~8 | Set × 8 | Edit Fields | 각 기사에 `keyword` 태그 부착 |
| 4 | Merge | Merge (append) | 8개 키워드 결과를 하나로 합침 |
| 5 | XML 파싱 | Code | XML에서 title/link/pubDate/source 추출 |
| 6 | 중복 제거 | Code | 유사 제목 기사 제거 (유사도 > 50%) |
| 7 | Claude 관련성 판단 | HTTP Request | Claude Haiku API 호출, 관련성 판단 + 요약 |
| 8 | Claude 응답 파싱 | Code | Claude 응답 JSON 파싱 + 원본 데이터 병합 |
| 9 | 관련 기사 필터 | IF | `relevant = true`인 기사만 통과 |
| 10 | Supabase 저장 | Supabase | `articles` 테이블에 Insert |

---

## 4. 수집 키워드 (8개)

| 키워드 | 언어 | 국가 |
|---|---|---|
| 고객경험 CX | ko | KR |
| CS 자동화 | ko | KR |
| VOC 분석 | ko | KR |
| CRM 플랫폼 | ko | KR |
| 고객 데이터 플랫폼 | ko | KR |
| 고객 충성도 | ko | KR |
| AI 고객서비스 | ko | KR |
| customer experience trends | en | US |

키워드 추가/삭제 시 HTTP Request + Set 노드를 쌍으로 추가/삭제.

---

## 5. 주요 설계 결정

### 5.1 왜 HTTP Request 8개 + Merge 구조인가?

- 초기에는 Code 노드 1개로 fetch 처리를 시도했으나, 현재 n8n 환경에서 `fetch`, `axios`, `$http`, `require('https')` 모두 사용 불가
- HTTP Request 노드는 n8n 내장 기능이라 어떤 환경에서도 안정적
- 유료(n8n Cloud) 환경으로 이관 시 Code 노드 1개 구조로 교체 검토 예정

### 5.2 왜 Set 노드로 keyword를 태그하는가?

- HTTP Request 응답에는 어떤 URL로 요청했는지 정보가 없음
- Merge 이후 어떤 키워드에서 온 기사인지 구분하려면 각 RSS 결과에 수동으로 keyword를 심어야 함

### 5.3 왜 중복 제거를 Claude 호출 전에 하는가?

- 동일 사건을 여러 언론사가 동시에 보도하는 경우가 많음
- Claude API 호출 전에 걸러내면 API 비용 절감
- 유사도 기준 50%는 "같은 사건/다른 표현"은 걸러내고, "다른 주제/비슷한 키워드"는 통과시키는 밸런스

### 5.4 왜 Claude 응답 파싱에서 `$('XML 파싱').all()[i]`로 역참조하는가?

- HTTP Request 노드가 응답을 받으면 원본 데이터(title, link 등)를 덮어씀
- Claude 응답에는 `relevant`, `score`, `summary`만 남음
- 같은 순번(i)의 XML 파싱 결과를 다시 가져와서 병합하는 방식으로 해결

---

## 6. Claude API 설정

| 항목 | 값 |
|---|---|
| 모델 | `claude-haiku-4-5-20251001` |
| max_tokens | 300 |
| Timeout | 30000ms (30초) |

### 프롬프트

```
다음 기사가 CX/CS/CSM/CRM 담당자에게 유용한지 판단해줘.
제목: {{ $json.title }}
JSON만 응답: {"relevant": true, "score": 8, "summary": "요약"}
```

### 응답 형식

```json
{
  "relevant": true,
  "score": 8,
  "summary": "한 줄 요약 (50자 이내)"
}
```

---

## 7. Supabase 저장 매핑

`articles` 테이블 Insert 시 필드 매핑:

| Supabase 컬럼 | n8n 값 |
|---|---|
| title | `{{ $json.title }}` |
| url | `{{ $json.link }}` |
| source | `{{ $json.source }}` |
| keyword | `{{ $json.keyword }}` |
| summary | `{{ $json.summary }}` |
| score | `{{ $json.score }}` |
| is_published | (기본값 false) |

---

## 8. 현재 알려진 제약

| 항목 | 내용 | 해결 방안 |
|---|---|---|
| Claude API 호출 속도 | 37개 기사 순차 처리 시 시간 소요 큼 | 유료 환경 이관 후 병렬 처리 검토 |
| Code 노드 라이브러리 제약 | fetch/axios 등 외부 모듈 사용 불가 | 유료 환경에서는 대부분 해결 예상 |
| 키워드 감지 로직 | URL 디코딩 기반 매칭은 불안정 | Set 노드로 직접 태깅하는 방식으로 해결 |

---

## 9. 향후 개선 사항

- [ ] 기사 본문 크롤링 기반 정밀 중복 판단
- [ ] Claude API 병렬 호출 (유료 환경 이관 후)
- [ ] 실패 기사 재시도 로직
- [ ] 일별 수집 결과 요약 알림 (Slack/Email)

---

*이 문서는 n8n 워크플로우 변경 시 함께 업데이트 필요.*
