[README.md](https://github.com/user-attachments/files/26890169/README.md)
# CX Lab

> CX / CSM / CRM 실무자를 위한 뉴스 큐레이션 & 커뮤니티 플랫폼

---

## 프로젝트 개요

CX(고객경험) / CSM(고객성공) / CRM 담당자를 위한 버티컬 커뮤니티.  
업계 뉴스를 자동 수집·큐레이션하고, 실무자 간 경험을 나누는 공간을 만들고 있습니다.

## 기술 스택

| 역할 | 도구 |
|---|---|
| 자동화 | n8n (셀프호스팅) |
| AI 필터링 | Claude API (Haiku) |
| 데이터베이스 | Supabase |
| 프론트엔드 | Lovable |

## 개발 Phase

| Phase | 내용 | 상태 |
|---|---|---|
| Phase 1 | n8n 뉴스 수집 파이프라인 | 🔲 진행 전 |
| Phase 2 | 관리자 검토 & 기사 발행 | 🔲 진행 전 |
| Phase 3 | Lovable 뉴스 피드 프론트엔드 | 🔲 진행 전 |
| Phase 4 | 회원 가입 & 커뮤니티 게시판 | 🔲 진행 전 |
| Phase 5 | 데이터 분석 & 확장 | 🔲 진행 전 |

## 문서

- [PRD (제품 요구사항 문서)](./docs/PRD.md)
- [DB 스키마](./supabase/schema.sql)
- [n8n 워크플로우](./n8n/workflows/)

## 디렉토리 구조

```
cx-lab/
├── docs/                  기획 문서
│   ├── PRD.md
│   ├── architecture.md
│   └── decisions/         주요 결정 기록
├── n8n/
│   └── workflows/         n8n Export JSON 파일
├── supabase/
│   └── schema.sql         DB 테이블 정의
└── lovable/
    └── components.md      UI 컴포넌트 메모
```

---

*last updated: 2026-04-20*
