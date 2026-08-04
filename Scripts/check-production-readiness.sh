#!/bin/sh

set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

failures=0
warnings=0

pass() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; warnings=$((warnings + 1)); }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }

if rg -q 'IPHONEOS_DEPLOYMENT_TARGET = 17\.0;' poco.xcodeproj/project.pbxproj; then
  pass 'Deployment Target includes iOS 17.0'
else
  fail 'Deployment Target iOS 17.0 was not found'
fi

if git check-ignore -q Config/Secrets.xcconfig && ! git ls-files --error-unmatch Config/Secrets.xcconfig >/dev/null 2>&1; then
  pass 'Config/Secrets.xcconfig is ignored and untracked'
else
  fail 'Config/Secrets.xcconfig must be ignored and untracked'
fi

tracked_files=$(git ls-files)
if [ -n "$tracked_files" ] && printf '%s\n' "$tracked_files" | xargs rg -l -e 'ghp_[A-Za-z0-9]{20,}' -e 'github_pat_[A-Za-z0-9_]+' -e 'SUPABASE_SERVICE_ROLE_KEY[[:space:]]*=[[:space:]]*[^[:space:]$]+' >/dev/null 2>&1; then
  fail 'A credential-shaped value exists in a tracked file (value intentionally hidden)'
else
  pass 'No obvious GitHub PAT or Supabase service-role assignment in tracked files'
fi

if [ -n "$(git log --all -G 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]+|SUPABASE_SERVICE_ROLE_KEY[[:space:]]*=' --format='%H' 2>/dev/null)" ]; then
  fail 'A credential-shaped value may exist in Git history (value intentionally hidden)'
else
  pass 'No obvious GitHub PAT or Supabase service-role assignment in Git history'
fi

if [ -f Config/Secrets.xcconfig ]; then
  pass 'Local Secrets.xcconfig exists'
else
  warn 'Local Secrets.xcconfig is missing; Supabase builds cannot connect to production'
fi

if rg -q '^POCO_APP_STORE_URL = https:\/\$\(\)\/apps\.apple\.com/' Config/Shared.xcconfig; then
  pass 'App Store QR URL uses an Apple HTTPS host'
else
  fail 'POCO_APP_STORE_URL must use apps.apple.com'
fi

if rg -q '^POCO_APP_STORE_URL = .*\/search\?term=Poco$' Config/Shared.xcconfig; then
  warn 'App Store QR still uses the temporary Poco search URL'
else
  pass 'App Store QR no longer uses the temporary search URL'
fi

if [ -f supabase/functions/sync-storekit-membership/index.ts ]; then
  pass 'StoreKit membership verification Edge Function exists'
else
  fail 'StoreKit membership verification Edge Function is missing (README contract only)'
fi

if command -v supabase >/dev/null 2>&1; then
  pass "Supabase CLI is installed ($(supabase --version))"
else
  warn 'Supabase CLI is not installed'
fi

if find poco -name PrivacyInfo.xcprivacy -print -quit | grep -q .; then
  pass 'Privacy Manifest exists'
else
  warn 'PrivacyInfo.xcprivacy was not found'
fi

if rg -q 'DCAppAttestService|AppAttest' poco supabase/functions -g '*.{swift,ts}' 2>/dev/null; then
  pass 'App Attest implementation marker exists'
else
  warn 'App Attest verification is not implemented'
fi

if rg -q 'UNUserNotificationCenter|registerForRemoteNotifications' poco -g '*.swift' 2>/dev/null; then
  pass 'APNs client registration marker exists'
else
  warn 'APNs client registration is not implemented'
fi

if rg -q 'POCO_AD_PROVIDER = placeholder' Config/Shared.xcconfig; then
  warn 'Ad provider is still placeholder'
else
  pass 'Ad provider is not the placeholder default'
fi

migration_count=$(find supabase/migrations -type f -name '*.sql' | wc -l | tr -d ' ')
pass "Supabase migration files present: $migration_count"

required_rpc_grants='
answer_question
browse_projects
claim_daily_login_bonus
claim_star_coin_event
equip_project_background
equip_project_badge
feedback_submission_count
get_project
get_project_slot_status
gift_profile_badge
mark_notification_read
moderate_feedback
my_feedbacks
my_liked_feedbacks
my_questions
purchase_star_item
redeem_project_slot
refresh_my_achievement_stamps
report_feedback
report_question
send_question
soft_delete_project
submit_feedback
submit_rights_holder_request
update_question
withdraw_question
'

missing_rpc_grants=''
for rpc_name in $required_rpc_grants; do
  if ! rg -q "grant execute on function public\\.${rpc_name}\\(" supabase/migrations; then
    missing_rpc_grants="${missing_rpc_grants} ${rpc_name}"
  fi
done

if [ -z "$missing_rpc_grants" ]; then
  pass 'Every RPC called by the iOS app has an explicit function GRANT in migrations'
else
  fail "Missing explicit RPC GRANT:${missing_rpc_grants}"
fi

if rg -q 'auth\.role\(\)' supabase/migrations; then
  warn 'Historical migrations still use deprecated auth.role(); final effective definitions must be verified'
else
  pass 'No deprecated auth.role() usage found in migrations'
fi

printf '\nSummary: %s failure(s), %s warning(s)\n' "$failures" "$warnings"

if [ "$failures" -ne 0 ]; then
  exit 1
fi
