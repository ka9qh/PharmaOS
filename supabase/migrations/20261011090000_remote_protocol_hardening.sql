-- PharmaOS: canonical remote-control protocol and tenant isolation.
-- Apply with `supabase db push` only after the companion Edge Functions are deployed.
-- This migration is additive: it preserves existing commands, chats and frames.

begin;

-- Canonical command fields.  Older clients used command_type/command_payload;
-- keep those columns temporarily so in-flight records are not lost.
alter table public.remote_commands
  add column if not exists type text,
  add column if not exists payload jsonb,
  add column if not exists device_id text,
  add column if not exists result_message text,
  add column if not exists claimed_at timestamptz;

update public.remote_commands
set type = coalesce(type, to_jsonb(remote_commands) ->> 'command_type'),
    payload = coalesce(payload, (to_jsonb(remote_commands) -> 'command_payload'), '{}'::jsonb)
where type is null or payload is null;

alter table public.remote_commands
  alter column type set not null,
  alter column payload set default '{}'::jsonb;

-- Canonical chat fields.  `read_at` is retained as the single read marker.
alter table public.owner_chat_messages
  add column if not exists device_id text,
  add column if not exists sender_name text,
  add column if not exists sender_role text,
  add column if not exists attachment_url text,
  add column if not exists read_at timestamptz;

-- Canonical stream fields; the old stream_type/frame_data fields are preserved
-- for historic compatibility, but clients must use channel/frame_base64 from now on.
alter table public.cloud_stream_frames
  add column if not exists channel text,
  add column if not exists device_id text,
  add column if not exists frame_base64 text,
  add column if not exists fps integer default 15,
  add column if not exists timestamp timestamptz default now();

update public.cloud_stream_frames
set channel = coalesce(channel, to_jsonb(cloud_stream_frames) ->> 'stream_type'),
    frame_base64 = coalesce(frame_base64, to_jsonb(cloud_stream_frames) ->> 'frame_data'),
    timestamp = coalesce(timestamp, created_at)
where channel is null or frame_base64 is null;

create index if not exists remote_commands_pending_target_idx
  on public.remote_commands (pharmacy_id, branch_id, device_id, created_at)
  where status = 'pending';
create index if not exists owner_chat_messages_target_idx
  on public.owner_chat_messages (pharmacy_id, branch_id, created_at);

-- Frames are not a video transport.  Retain only a short diagnostic history
-- until all clients have moved to LiveKit; this prevents unbounded database growth.
create index if not exists cloud_stream_frames_expiry_idx
  on public.cloud_stream_frames (created_at);

-- Remove the insecure public policies.  Policies below require a signed JWT
-- with pharmacy_id and role claims minted by the server-side token function.
drop policy if exists "Allow pharmacy full access to own data" on public.pharmacies;
drop policy if exists "Allow branch access to own data" on public.branches;
drop policy if exists "Allow medicines access to own pharmacy" on public.cloud_medicines;
drop policy if exists "Allow sales access to own pharmacy" on public.cloud_sales;
drop policy if exists "Allow sale items access to own pharmacy" on public.cloud_sale_items;
drop policy if exists "Allow closings access to own pharmacy" on public.cloud_day_closings;
drop policy if exists "Allow customers access to own pharmacy" on public.cloud_customers;
drop policy if exists "Allow suppliers access to own pharmacy" on public.cloud_suppliers;
drop policy if exists "Allow expenses access to own pharmacy" on public.cloud_expenses;
drop policy if exists "Allow batches access to own pharmacy" on public.cloud_batches;
drop policy if exists "Allow tele consultations access to own pharmacy" on public.cloud_tele_consultations;
drop policy if exists "backups_policy" on public.cloud_backups;
drop policy if exists "queue_policy" on public.pending_backup_queue;
drop policy if exists "audit_policy" on public.admin_audit_log;
drop policy if exists "Allow remote commands access to own pharmacy" on public.remote_commands;
drop policy if exists "Allow owner chat messages access to own pharmacy" on public.owner_chat_messages;
drop policy if exists "Allow stream frames access to own pharmacy" on public.cloud_stream_frames;
drop policy if exists "Allow owner audit actions access to own pharmacy" on public.owner_audit_actions;

-- The policies are deliberately installed only for the remote-control tables.
-- Existing data-sync tables require their own tested claim-aware migration.
alter table public.remote_commands enable row level security;
alter table public.owner_chat_messages enable row level security;
alter table public.cloud_stream_frames enable row level security;

create policy "tenant remote commands" on public.remote_commands
  for all to authenticated
  using (pharmacy_id = ((auth.jwt() ->> 'pharmacy_id')::bigint))
  with check (pharmacy_id = ((auth.jwt() ->> 'pharmacy_id')::bigint));
create policy "tenant owner chat" on public.owner_chat_messages
  for all to authenticated
  using (pharmacy_id = ((auth.jwt() ->> 'pharmacy_id')::bigint))
  with check (pharmacy_id = ((auth.jwt() ->> 'pharmacy_id')::bigint));
create policy "tenant stream diagnostics" on public.cloud_stream_frames
  for all to authenticated
  using (pharmacy_id = ((auth.jwt() ->> 'pharmacy_id')::bigint))
  with check (pharmacy_id = ((auth.jwt() ->> 'pharmacy_id')::bigint));

commit;
