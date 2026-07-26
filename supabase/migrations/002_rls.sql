begin;

alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.feedbacks enable row level security;
alter table public.feedback_likes enable row level security;

drop policy if exists "Profiles are publicly readable" on public.profiles;
create policy "Profiles are publicly readable"
  on public.profiles for select
  to anon, authenticated
  using (true);

drop policy if exists "Users create their own profile" on public.profiles;
create policy "Users create their own profile"
  on public.profiles for insert
  to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "Users update their own profile" on public.profiles;
create policy "Users update their own profile"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "Published projects are publicly readable" on public.projects;
create policy "Published projects are publicly readable"
  on public.projects for select
  to anon, authenticated
  using (is_published or creator_id = (select auth.uid()));

drop policy if exists "Creators insert their own projects" on public.projects;
create policy "Creators insert their own projects"
  on public.projects for insert
  to authenticated
  with check (creator_id = (select auth.uid()));

drop policy if exists "Creators update their own projects" on public.projects;
create policy "Creators update their own projects"
  on public.projects for update
  to authenticated
  using (creator_id = (select auth.uid()))
  with check (creator_id = (select auth.uid()));

drop policy if exists "Creators delete their own projects" on public.projects;
create policy "Creators delete their own projects"
  on public.projects for delete
  to authenticated
  using (creator_id = (select auth.uid()));

drop policy if exists "Visible feedback is readable" on public.feedbacks;
create policy "Visible feedback is readable"
  on public.feedbacks for select
  to anon, authenticated
  using (
    is_public
    or sender_id = (select auth.uid())
    or exists (
      select 1
      from public.projects
      where projects.id = feedbacks.project_id
        and projects.creator_id = (select auth.uid())
    )
  );

drop policy if exists "Guests and users submit feedback" on public.feedbacks;
create policy "Guests and users submit feedback"
  on public.feedbacks for insert
  to anon, authenticated
  with check (
    (
      likes_count = 0
      and exists (
        select 1
        from public.projects
        where projects.id = feedbacks.project_id
          and projects.is_published
      )
      and (
        (
          (select auth.uid()) is null
          and sender_id is null
        )
        or
        (
          (select auth.uid()) is not null
          and (sender_id is null or sender_id = (select auth.uid()))
        )
      )
    )
  );

drop policy if exists "Users update their own feedback" on public.feedbacks;
create policy "Users update their own feedback"
  on public.feedbacks for update
  to authenticated
  using (sender_id = (select auth.uid()))
  with check (sender_id = (select auth.uid()));

drop policy if exists "Users delete their own feedback" on public.feedbacks;
create policy "Users delete their own feedback"
  on public.feedbacks for delete
  to authenticated
  using (sender_id = (select auth.uid()));

drop policy if exists "Feedback likes are publicly readable" on public.feedback_likes;
create policy "Feedback likes are publicly readable"
  on public.feedback_likes for select
  to anon, authenticated
  using (true);

drop policy if exists "Users add their own likes" on public.feedback_likes;
create policy "Users add their own likes"
  on public.feedback_likes for insert
  to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "Users remove their own likes" on public.feedback_likes;
create policy "Users remove their own likes"
  on public.feedback_likes for delete
  to authenticated
  using (user_id = (select auth.uid()));

commit;
