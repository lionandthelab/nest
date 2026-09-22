-- media_assets.term_id를 반 배정에서 자동으로 채운다
--
-- 20260922090000에서 term_id를 추가하면서 기존 행은 백필했지만, 새 행은
-- 클라이언트가 term_id를 제대로 실어 보내야만 채워진다. 앨범이 아닌 경로
-- (커뮤니티 게시글 첨부 등)로 들어온 미디어는 반만 알고 학기는 모른 채 남고,
-- 그러면 학기 앨범에서 조용히 사라진다. 반이 있으면 학기는 항상 유도 가능하므로
-- 트리거로 못 박는다.

create or replace function public.sync_media_asset_term()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.class_group_id is not null then
    select cg.term_id
      into new.term_id
    from public.class_groups cg
    where cg.id = new.class_group_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_media_assets_term on public.media_assets;
create trigger trg_media_assets_term
before insert or update of class_group_id on public.media_assets
for each row execute function public.sync_media_asset_term();
