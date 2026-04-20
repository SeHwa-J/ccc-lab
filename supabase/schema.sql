-- CX Lab — Supabase 스키마 정의
-- 버전: v0.1 | 작성일: 2026-04-20

-- 수집된 기사
create table articles (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  url           text not null unique,
  source        text,
  keyword       text,
  summary       text,
  editor_note   text,
  score         int check (score between 1 and 10),
  is_published  boolean default false,
  published_at  timestamptz,
  created_at    timestamptz default now()
);

-- 게시글 (자유 게시판 + 기사 연결 토론 통합)
-- article_id null → 자유 게시판
-- article_id 있음 → 기사 연결 토론
create table posts (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  content       text not null,
  author_id     uuid references auth.users on delete cascade,
  article_id    uuid references articles on delete set null,
  created_at    timestamptz default now()
);

-- 댓글
create table comments (
  id            uuid primary key default gen_random_uuid(),
  post_id       uuid references posts on delete cascade,
  author_id     uuid references auth.users on delete cascade,
  content       text not null,
  created_at    timestamptz default now()
);

-- 회원 프로필
create table profiles (
  id            uuid primary key references auth.users on delete cascade,
  nickname      text,
  job_title     text,
  company_type  text,
  created_at    timestamptz default now()
);

-- RLS (Row Level Security) 활성화
alter table articles  enable row level security;
alter table posts     enable row level security;
alter table comments  enable row level security;
alter table profiles  enable row level security;

-- 정책: 기사 - 누구나 발행된 기사 조회 가능
create policy "published articles are public"
  on articles for select
  using (is_published = true);

-- 정책: 게시글 - 누구나 조회, 로그인 회원만 작성
create policy "posts are public"
  on posts for select using (true);

create policy "authenticated users can insert posts"
  on posts for insert
  with check (auth.uid() = author_id);

create policy "users can update own posts"
  on posts for update
  using (auth.uid() = author_id);

create policy "users can delete own posts"
  on posts for delete
  using (auth.uid() = author_id);

-- 정책: 댓글 - 누구나 조회, 로그인 회원만 작성
create policy "comments are public"
  on comments for select using (true);

create policy "authenticated users can insert comments"
  on comments for insert
  with check (auth.uid() = author_id);

-- 정책: 프로필 - 본인만 수정
create policy "profiles are public"
  on profiles for select using (true);

create policy "users can update own profile"
  on profiles for update
  using (auth.uid() = id);
