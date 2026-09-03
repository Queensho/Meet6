create index if not exists admin_audit_log_action_created_idx
  on admin_audit_log(action, created_at desc);

create index if not exists admin_audit_log_target_created_idx
  on admin_audit_log(target_type, target_id, created_at desc);

create index if not exists user_bans_admin_created_idx
  on user_bans(admin_user_id, created_at desc);

create index if not exists user_bans_revoked_created_idx
  on user_bans(revoked_by, revoked_at desc);
