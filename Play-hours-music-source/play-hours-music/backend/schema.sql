-- Run once in the SQL editor of a NEW Supabase project.
-- All public profile fields are intentionally public; email stays in auth.users.
begin;
create extension if not exists pg_trgm with schema extensions;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 artist_name text not null check(length(trim(artist_name)) between 1 and 60),
 bio text not null default '' check(length(bio) <= 500)
);
create table public.tracks (
 id uuid primary key,
 owner_id uuid not null references public.profiles(id) on delete cascade,
 title text not null check(length(trim(title)) between 1 and 120),
 genre text not null check(length(trim(genre)) between 1 and 50),
 lyrics text not null default '' check(length(lyrics) <= 20000),
 audio_path text not null,
 cover_path text not null,
 audio_url text not null check(audio_url like 'https://%'),
 cover_url text not null check(cover_url like 'https://%'),
 created_at timestamptz not null default now(),
 check(audio_path = owner_id::text || '/' || id::text || '.mp3'),
 check(cover_path = owner_id::text || '/' || id::text || '.jpg')
);
create table public.likes (
 track_id uuid not null references public.tracks(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 primary key(track_id,user_id)
);
create table public.comments (
 id uuid primary key default gen_random_uuid(),
 track_id uuid not null references public.tracks(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(length(trim(body)) between 1 and 1000),
 created_at timestamptz not null default now()
);
create index tracks_recent on public.tracks(created_at desc,id);
create index tracks_owner on public.tracks(owner_id,created_at desc);
create index comments_track on public.comments(track_id,created_at desc);

create function public.new_music_user() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.profiles(id,artist_name) values(new.id,
   left(coalesce(nullif(trim(new.raw_user_meta_data->>'artist_name'),''),'Новый артист'),60));
 return new;
end; $$;
create trigger on_music_signup after insert on auth.users for each row execute function public.new_music_user();
revoke all on function public.new_music_user() from public;

alter table public.profiles enable row level security;
alter table public.tracks enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
create policy profiles_read on public.profiles for select to anon,authenticated using(true);
create policy profiles_edit on public.profiles for update to authenticated using(id = (select auth.uid())) with check(id = (select auth.uid()));
create policy tracks_read on public.tracks for select to anon,authenticated using(true);
create policy tracks_add on public.tracks for insert to authenticated with check(owner_id = (select auth.uid()));
create policy tracks_remove on public.tracks for delete to authenticated using(owner_id = (select auth.uid()));
create policy likes_read on public.likes for select to anon,authenticated using(true);
create policy likes_add on public.likes for insert to authenticated with check(user_id = (select auth.uid()));
create policy likes_update on public.likes for update to authenticated using(user_id = (select auth.uid())) with check(user_id = (select auth.uid()));
create policy likes_remove on public.likes for delete to authenticated using(user_id = (select auth.uid()));
create policy comments_read on public.comments for select to anon,authenticated using(true);
create policy comments_add on public.comments for insert to authenticated with check(user_id = (select auth.uid()));
create policy comments_remove on public.comments for delete to authenticated using(user_id = (select auth.uid()));
grant select on public.profiles,public.tracks,public.likes,public.comments to anon,authenticated;
grant update(artist_name,bio) on public.profiles to authenticated;
grant insert,delete on public.tracks,public.likes,public.comments to authenticated;
grant update on public.likes to authenticated;

-- SECURITY INVOKER keeps the caller's row policies in force.
-- Search applies to the whole catalogue, not just the first visible page.
create function public.catalog(search_text text default '', only_mine boolean default false, page_offset integer default 0)
returns table(id uuid,owner_id uuid,title text,genre text,lyrics text,audio_url text,cover_url text,artist_name text)
language sql stable security invoker set search_path = public,extensions as $$
 with q as (select replace(lower(left(trim(search_text),160)),'ё','е') as term)
 select t.id,t.owner_id,t.title,t.genre,t.lyrics,t.audio_url,t.cover_url,p.artist_name
 from public.tracks t join public.profiles p on p.id=t.owner_id cross join q
 where (not only_mine or t.owner_id=auth.uid()) and
 (q.term='' or strpos(replace(lower(t.title || ' ' || p.artist_name || ' ' || t.genre),'ё','е'),q.term)>0
 or extensions.similarity(replace(lower(t.title),'ё','е'),q.term)>0.22)
 order by case when q.term='' then 0 else extensions.similarity(replace(lower(t.title),'ё','е'),q.term) end desc,t.created_at desc,t.id
 limit 50 offset greatest(page_offset,0);
$$;
revoke all on function public.catalog(text,boolean,integer) from public;
grant execute on function public.catalog(text,boolean,integer) to anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('music','music',true,52428800,array['audio/mpeg','image/jpeg']);
create policy music_upload on storage.objects for insert to authenticated with check(
 bucket_id='music' and (storage.foldername(name))[1]=(select auth.uid())::text
 and lower(storage.extension(name)) in ('mp3','jpg')
);
create policy music_owner_read on storage.objects for select to authenticated using(
 bucket_id='music' and (storage.foldername(name))[1]=(select auth.uid())::text
);
create policy music_delete on storage.objects for delete to authenticated using(
 bucket_id='music' and (storage.foldername(name))[1]=(select auth.uid())::text
);
commit;
