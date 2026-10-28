-- 글귀 아카이브: Supabase SQL Editor에서 전체 실행
create extension if not exists pgcrypto;

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  text text not null check (char_length(trim(text)) between 1 and 1500),
  author text check (author is null or char_length(author) <= 120),
  source text check (source is null or char_length(source) <= 180),
  place text not null check (char_length(trim(place)) between 1 and 100),
  posted_on date,
  tags text[] not null default '{}',
  image_url text,
  image_path text,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete cascade,
  author_name text not null default '익명' check (char_length(trim(author_name)) between 1 and 40),
  body text not null check (char_length(trim(body)) between 1 and 500),
  status text not null default 'visible' check (status in ('visible','hidden')),
  created_at timestamptz not null default now()
);

create table if not exists public.comment_reports (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.comments(id) on delete cascade,
  reason text not null check (char_length(trim(reason)) between 1 and 300),
  created_at timestamptz not null default now(),
  resolved boolean not null default false
);

create index if not exists quotes_published_created_idx on public.quotes(published, created_at desc);
create index if not exists quotes_place_idx on public.quotes(place);
create index if not exists comments_quote_status_created_idx on public.comments(quote_id, status, created_at desc);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists quotes_set_updated_at on public.quotes;
create trigger quotes_set_updated_at before update on public.quotes for each row execute function public.set_updated_at();

alter table public.quotes enable row level security;
alter table public.comments enable row level security;
alter table public.comment_reports enable row level security;

-- Admins must be explicitly granted app_metadata.role = "admin" by a trusted project owner.
-- Never allow users to self-assign this role through user-editable metadata.
create or replace function public.is_archive_admin()
returns boolean language sql stable as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false);
$$;

-- Public visitors can read published quotes only.
drop policy if exists "public read published quotes" on public.quotes;
create policy "public read published quotes" on public.quotes for select to anon, authenticated using (published = true or public.is_archive_admin());
drop policy if exists "admin insert quotes" on public.quotes;
create policy "admin insert quotes" on public.quotes for insert to authenticated with check (public.is_archive_admin());
drop policy if exists "admin update quotes" on public.quotes;
create policy "admin update quotes" on public.quotes for update to authenticated using (public.is_archive_admin()) with check (public.is_archive_admin());
drop policy if exists "admin delete quotes" on public.quotes;
create policy "admin delete quotes" on public.quotes for delete to authenticated using (public.is_archive_admin());

-- Anyone can read visible comments attached to a published quote.
drop policy if exists "public read visible comments" on public.comments;
create policy "public read visible comments" on public.comments for select to anon, authenticated using (status = 'visible' and exists (select 1 from public.quotes q where q.id = quote_id and q.published = true) or public.is_archive_admin());
-- Public guestbook-style comments; enforce content length in DB. Add CAPTCHA/rate limiting before broad promotion.
drop policy if exists "public insert comments" on public.comments;
create policy "public insert comments" on public.comments for insert to anon, authenticated with check (
  status = 'visible' and char_length(trim(author_name)) between 1 and 40 and char_length(trim(body)) between 1 and 500
  and exists (select 1 from public.quotes q where q.id = quote_id and q.published = true)
);
drop policy if exists "admin update comments" on public.comments;
create policy "admin update comments" on public.comments for update to authenticated using (public.is_archive_admin()) with check (public.is_archive_admin());
drop policy if exists "admin delete comments" on public.comments;
create policy "admin delete comments" on public.comments for delete to authenticated using (public.is_archive_admin());

-- Report insertion is public; only admins can review reports.
drop policy if exists "public submit comment reports" on public.comment_reports;
create policy "public submit comment reports" on public.comment_reports for insert to anon, authenticated with check (char_length(trim(reason)) between 1 and 300 and exists (select 1 from public.comments c where c.id = comment_id));
drop policy if exists "admin read reports" on public.comment_reports;
create policy "admin read reports" on public.comment_reports for select to authenticated using (public.is_archive_admin());
drop policy if exists "admin update reports" on public.comment_reports;
create policy "admin update reports" on public.comment_reports for update to authenticated using (public.is_archive_admin()) with check (public.is_archive_admin());

-- Create a public image bucket. Images are public to view; only archive admins can upload/change/delete.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('quote-photos', 'quote-photos', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "public view quote photos" on storage.objects;
create policy "public view quote photos" on storage.objects for select to anon, authenticated using (bucket_id = 'quote-photos');
drop policy if exists "admins upload quote photos" on storage.objects;
create policy "admins upload quote photos" on storage.objects for insert to authenticated with check (bucket_id = 'quote-photos' and public.is_archive_admin());
drop policy if exists "admins update quote photos" on storage.objects;
create policy "admins update quote photos" on storage.objects for update to authenticated using (bucket_id = 'quote-photos' and public.is_archive_admin()) with check (bucket_id = 'quote-photos' and public.is_archive_admin());
drop policy if exists "admins delete quote photos" on storage.objects;
create policy "admins delete quote photos" on storage.objects for delete to authenticated using (bucket_id = 'quote-photos' and public.is_archive_admin());

-- Optional: create initial quotes only after reviewing copyright and photo consent.
-- insert into public.quotes (text, author, source, place, posted_on, tags, published)
-- values ('예시 글귀를 여기에 입력하세요.', '작성자', '출처', '도서관', current_date, array['예시'], false);
