#!/usr/bin/env bash
# Constraint tests for the catalog. Every case asserts a specific rejection or
# a specific success.
set -uo pipefail

DB="${TEST_DB:-mk_test}"
MIGRATIONS="$(cd "$(dirname "$0")/../migrations" && pwd)"
PASS=0; FAIL=0

run_sql() { psql -v ON_ERROR_STOP=1 -q -d "$DB" -c "$1" 2>&1; }

expect_ok() {
  local name="$1" sql="$2" out
  if out=$(run_sql "$sql"); then
    PASS=$((PASS+1)); printf '  ok    %s\n' "$name"
  else
    FAIL=$((FAIL+1)); printf '  FAIL  %s\n        expected success, got: %s\n' "$name" "$(echo "$out" | head -2 | tr '\n' ' ')"
  fi
}

expect_fail() {
  local name="$1" sql="$2" want="$3" out
  if out=$(run_sql "$sql"); then
    FAIL=$((FAIL+1)); printf '  FAIL  %s\n        expected rejection, but it was accepted\n' "$name"
  elif echo "$out" | grep -qi "$want"; then
    PASS=$((PASS+1)); printf '  ok    %s\n' "$name"
  else
    FAIL=$((FAIL+1)); printf '  FAIL  %s\n        rejected, but not for %s: %s\n' "$name" "$want" "$(echo "$out" | head -2 | tr '\n' ' ')"
  fi
}

echo "Rebuilding $DB"
dropdb --if-exists "$DB" >/dev/null 2>&1
createdb "$DB"
for file in "$MIGRATIONS"/*.sql; do
  psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$file" || { echo "migration failed: $file"; exit 1; }
done

psql -q -d "$DB" <<'SEED'
insert into marketplace.publishers (id, slug, name)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'culturereset', 'CultureReset');
insert into marketplace.products (id, slug, publisher_id, name, status)
  values ('bbbbbbbb-0000-0000-0000-000000000001', 'qr-menu', 'aaaaaaaa-0000-0000-0000-000000000001', 'QR Menu', 'published');
insert into marketplace.product_versions (id, product_id, version, manifest, status)
  values ('cccccccc-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', '1.0.0', '{"product":"qr-menu"}', 'published'),
         ('cccccccc-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000001', '1.1.0', '{"product":"qr-menu"}', 'published');
SEED

echo
echo "catalog identifiers"
expect_fail "product slug must be a lowercase contract id" \
  "insert into marketplace.products (slug, publisher_id, name) values ('QR_Menu','aaaaaaaa-0000-0000-0000-000000000001','x');" "contract_id"
expect_fail "version must be semver" \
  "insert into marketplace.product_versions (product_id, version, manifest) values ('bbbbbbbb-0000-0000-0000-000000000001','1.0','{}');" "semver"
expect_fail "the same version cannot be published twice for one product" \
  "insert into marketplace.product_versions (product_id, version, manifest) values ('bbbbbbbb-0000-0000-0000-000000000001','1.0.0','{}');" "product_versions_product_id_version_key"

echo
echo "releases"
expect_ok "a version can be released as current stable" \
  "insert into marketplace.releases (product_version_id, product_id, channel, is_current)
   values ('cccccccc-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001','stable', true);"
expect_fail "a second version cannot also be current stable for the same product" \
  "insert into marketplace.releases (product_version_id, product_id, channel, is_current)
   values ('cccccccc-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000001','stable', true);" \
  "releases_one_current_per_channel"
expect_ok "a non-current release of another version is fine" \
  "insert into marketplace.releases (product_version_id, product_id, channel, is_current)
   values ('cccccccc-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000001','stable', false);"
expect_ok "the same product may be current on a different channel" \
  "insert into marketplace.releases (product_version_id, product_id, channel, is_current)
   values ('cccccccc-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000001','beta', true);"
expect_fail "a release cannot claim a product its version does not belong to" \
  "insert into marketplace.products (id, slug, publisher_id, name) values ('bbbbbbbb-0000-0000-0000-000000000002','other','aaaaaaaa-0000-0000-0000-000000000001','Other');
   insert into marketplace.releases (product_version_id, product_id, channel)
   values ('cccccccc-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002','stable');" \
  "foreign key"

echo
echo "declared sockets"
expect_fail "an unknown surface kind is rejected" \
  "insert into marketplace.declared_surfaces (product_version_id, kind, path)
   values ('cccccccc-0000-0000-0000-000000000001','billboard','/x');" "check constraint"
expect_fail "an unknown capability direction is rejected" \
  "insert into marketplace.declared_capabilities (product_version_id, capability_id, direction)
   values ('cccccccc-0000-0000-0000-000000000001','browser.open','maybe');" "check constraint"
expect_fail "a runtime below the minimum memory is rejected" \
  "insert into marketplace.runtime_requirements (product_version_id, kind, memory_mb)
   values ('cccccccc-0000-0000-0000-000000000001','container', 8);" "check constraint"

echo
echo "pricing"
expect_ok "a free product carries no amount" \
  "insert into marketplace.pricing (product_version_id, model) values ('cccccccc-0000-0000-0000-000000000001','free');"
expect_fail "a free product cannot carry a price" \
  "insert into marketplace.pricing (product_version_id, model, amount_cents, currency)
   values ('cccccccc-0000-0000-0000-000000000002','free', 500, 'USD');" "pricing_amount_matches_model"
expect_fail "a paid product must say what it costs" \
  "insert into marketplace.pricing (product_version_id, model) values ('cccccccc-0000-0000-0000-000000000002','flat');" \
  "pricing_amount_matches_model"
expect_ok "a paid product with an amount and currency is accepted" \
  "insert into marketplace.pricing (product_version_id, model, amount_cents, currency)
   values ('cccccccc-0000-0000-0000-000000000002','flat', 1500, 'USD');"

echo
if [ "$FAIL" -gt 0 ]; then echo "FAILED: $PASS passed, $FAIL failed"; exit 1; fi
echo "OK: $PASS passed"
