begin;

alter table public.questions
  add column if not exists edited_at timestamptz;

create or replace function public.update_question(
  p_question_id uuid,
  p_message text
)
returns table (
  id uuid,
  project_id uuid,
  project_title text,
  sender_id uuid,
  sender_name text,
  sender_avatar_name text,
  sender_avatar_url text,
  sender_handle text,
  creator_id uuid,
  creator_name text,
  creator_avatar_name text,
  creator_avatar_url text,
  creator_handle text,
  message text,
  answer text,
  status text,
  created_at timestamptz,
  answered_at timestamptz,
  withdrawn_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_message text := trim(p_message);
  target public.questions%rowtype;
begin
  if current_user_id is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, true) then
    raise exception 'Registered account required' using errcode = '42501';
  end if;
  if char_length(normalized_message) not between 1 and 500 then
    raise exception 'Invalid question' using errcode = '22023';
  end if;

  select question.* into target
  from public.questions as question
  where question.id = p_question_id
  for update;

  if not found then
    raise exception 'Question not found' using errcode = 'P0002';
  end if;
  if target.sender_id <> current_user_id then
    raise exception 'Not question sender' using errcode = '42501';
  end if;
  if target.status <> 'pending'
     or target.created_at <= now() - interval '30 days' then
    raise exception 'Question unavailable' using errcode = 'P0013';
  end if;
  if exists (
    select 1 from public.user_blocks as block
    where (block.blocker_id = current_user_id and block.blocked_profile_id = target.creator_id)
       or (block.blocker_id = target.creator_id and block.blocked_profile_id = current_user_id)
  ) then
    raise exception 'Interaction blocked' using errcode = '42501';
  end if;

  update public.questions
  set message = normalized_message,
      edited_at = case
        when target.message is distinct from normalized_message then now()
        else target.edited_at
      end
  where questions.id = p_question_id;

  return query
  select detail.* from private.question_details(p_question_id) as detail;
end;
$$;

comment on function public.update_question(uuid, text) is
  'Lets the registered sender correct a pending question without resetting its limits or creation time.';

revoke all on function public.update_question(uuid, text) from public, anon;
grant execute on function public.update_question(uuid, text) to authenticated;

commit;
