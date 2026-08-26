-- CyberCheck marketplace catalog.
--
-- This schema owns what products EXIST, their versions and releases. It does
-- not own product source code, and it does not own what any business has
-- installed -- that is cybercheck-core.

create schema if not exists marketplace;

-- Contract identifiers are lowercase, dot or hyphen separated. Same pattern the
-- contract validator enforces, restated here so bad data cannot reach the table.
create domain marketplace.contract_id as text
  check (value ~ '^[a-z0-9]+([.-][a-z0-9]+)*$');

create domain marketplace.semver as text
  check (value ~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$');

create table marketplace.publishers (
  id            uuid primary key default gen_random_uuid(),
  slug          marketplace.contract_id not null unique,
  name          text not null check (length(trim(name)) > 0),
  contact_email text,
  verified      boolean not null default false,
  created_at    timestamptz not null default now()
);

create table marketplace.categories (
  id        uuid primary key default gen_random_uuid(),
  slug      marketplace.contract_id not null unique,
  name      text not null,
  parent_id uuid references marketplace.categories (id) on delete set null
);

create table marketplace.products (
  id           uuid primary key default gen_random_uuid(),
  slug         marketplace.contract_id not null unique,
  publisher_id uuid not null references marketplace.publishers (id) on delete restrict,
  name         text not null check (length(trim(name)) > 0),
  description  text,
  icon         text,
  status       text not null default 'draft'
                 check (status in ('draft', 'published', 'deprecated', 'withdrawn')),
  created_at   timestamptz not null default now()
);

create table marketplace.product_categories (
  product_id  uuid not null references marketplace.products (id) on delete cascade,
  category_id uuid not null references marketplace.categories (id) on delete cascade,
  primary key (product_id, category_id)
);

-- The manifest is stored whole so a version is always reproducible and
-- auditable. The declared_* tables below are derived from it at publish time so
-- the catalog is queryable ("which products want menu.write?").
create table marketplace.product_versions (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null references marketplace.products (id) on delete cascade,
  version    marketplace.semver not null,
  manifest   jsonb not null,
  status     text not null default 'draft'
               check (status in ('draft', 'published', 'yanked')),
  created_at timestamptz not null default now(),
  unique (product_id, version),
  -- Lets releases carry product_id and prove it matches this version's product.
  unique (id, product_id)
);

create table marketplace.releases (
  id                 uuid primary key default gen_random_uuid(),
  product_version_id uuid not null references marketplace.product_versions (id) on delete cascade,
  -- Denormalised so the one-current-per-channel rule can be a real constraint.
  -- The composite foreign key below stops it drifting from the version's product.
  product_id         uuid not null references marketplace.products (id) on delete cascade,
  channel            text not null default 'stable'
                       check (channel in ('stable', 'beta', 'canary')),
  is_current         boolean not null default false,
  released_at        timestamptz not null default now(),
  released_by        text,
  notes              text,
  foreign key (product_version_id, product_id)
    references marketplace.product_versions (id, product_id) on delete cascade
);

-- A product's channel points at exactly one current release. Keyed on the
-- product, not the version: two versions of the same product both claiming to
-- be current stable is precisely the ambiguity this must prevent.
create unique index releases_one_current_per_channel
  on marketplace.releases (product_id, channel)
  where is_current;

create table marketplace.declared_permissions (
  product_version_id uuid not null references marketplace.product_versions (id) on delete cascade,
  permission_id      marketplace.contract_id not null,
  primary key (product_version_id, permission_id)
);

create table marketplace.declared_capabilities (
  product_version_id uuid not null references marketplace.product_versions (id) on delete cascade,
  capability_id      marketplace.contract_id not null,
  direction          text not null check (direction in ('provides', 'requires')),
  primary key (product_version_id, capability_id, direction)
);

create table marketplace.declared_events (
  product_version_id uuid not null references marketplace.product_versions (id) on delete cascade,
  event_id           marketplace.contract_id not null,
  direction          text not null check (direction in ('emits', 'subscribes')),
  primary key (product_version_id, event_id, direction)
);

create table marketplace.declared_surfaces (
  id                  uuid primary key default gen_random_uuid(),
  product_version_id  uuid not null references marketplace.product_versions (id) on delete cascade,
  kind                text not null
                        check (kind in ('dashboard', 'public', 'direct-url', 'settings', 'onboarding')),
  path                text not null check (length(trim(path)) > 0),
  title               text,
  icon                text,
  requires_permission marketplace.contract_id,
  unique (product_version_id, kind, path)
);

create table marketplace.declared_bindings (
  product_version_id uuid not null references marketplace.product_versions (id) on delete cascade,
  dataset            marketplace.contract_id not null,
  access             text not null check (access in ('read', 'read-write')),
  primary key (product_version_id, dataset)
);

create table marketplace.runtime_requirements (
  product_version_id uuid primary key references marketplace.product_versions (id) on delete cascade,
  kind               text not null
                       check (kind in ('container', 'service', 'static', 'android', 'browser')),
  image              text,
  compose_file       text,
  memory_mb          integer check (memory_mb >= 16),
  cpu                numeric(4, 2) check (cpu >= 0.1),
  health_endpoint    text,
  health_interval_seconds integer check (health_interval_seconds >= 5)
);

-- Prerequisites the installer checks before it will install this version.
create table marketplace.install_requirements (
  id                 uuid primary key default gen_random_uuid(),
  product_version_id uuid not null references marketplace.product_versions (id) on delete cascade,
  requirement_kind   text not null
                       check (requirement_kind in ('capability', 'dataset', 'product', 'platform-version')),
  requirement_value  text not null,
  minimum_version    marketplace.semver,
  unique (product_version_id, requirement_kind, requirement_value)
);

create table marketplace.pricing (
  product_version_id uuid primary key references marketplace.product_versions (id) on delete cascade,
  model              text not null check (model in ('free', 'flat', 'usage', 'tiered')),
  entitlement_key    marketplace.contract_id,
  amount_cents       integer check (amount_cents >= 0),
  currency           char(3),
  -- A priced model has to say what it costs; free must not.
  constraint pricing_amount_matches_model check (
    (model = 'free' and amount_cents is null and currency is null)
    or (model <> 'free' and amount_cents is not null and currency is not null)
  )
);

create index products_publisher_idx        on marketplace.products (publisher_id);
create index product_versions_product_idx  on marketplace.product_versions (product_id);
create index declared_permissions_perm_idx on marketplace.declared_permissions (permission_id);
create index declared_surfaces_kind_idx    on marketplace.declared_surfaces (kind);
