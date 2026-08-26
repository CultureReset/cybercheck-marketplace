# cybercheck-marketplace

**The catalog.** This is Step 3 of the App Store foundation.

The marketplace owns what products *exist*: publishers, products, versions,
releases, and everything a version declares. It owns neither product source code
nor installation state.

| Concern | Owner |
|---|---|
| What products *exist* | **this repo** |
| What a business *has installed* | `cybercheck-core` |
| Canonical business facts | `cybercheck-data-schema` |
| Product source code | the product's own repo |

## Tables

**Catalog** — `publishers`, `products`, `categories`, `product_categories`,
`product_versions`, `releases`

**What a version declares** — `declared_permissions`, `declared_capabilities`,
`declared_events`, `declared_surfaces`, `declared_bindings`,
`runtime_requirements`, `install_requirements`, `pricing`

## The plugin catalog

`.claude-plugin/marketplace.json` is a second, much smaller catalog that works
today. It indexes the agent tooling CyberCheck builds with, so a developer gets
all of it with two commands:

```bash
/plugin marketplace add culturereset/cybercheck-marketplace
/plugin install cloudflare@cybercheck
```

Fourteen plugins, carrying 198 skills, 17 slash commands, 8 subagents and 8 MCP
servers between them. Every entry was installed and enabled before it was
committed.

| Plugin | What it is |
|---|---|
| `grok-build` | Grok Build bridge — review, critique, delegate. Needs the `grok` CLI on PATH. |
| `cloudflare` | Workers, Pages, D1, R2, KV |
| `vercel` | Deployments, logs, domains — where the API and dashboards ship |
| `netlify`, `railway` | The other two deploy targets |
| `stripe` | Payments, subscriptions, webhooks |
| `mongodb`, `mongodb-atlas` | Queries, schema, aggregation, cluster admin |
| `browser-use`, `browser-use-qa` | Browser automation and QA flows |
| `superpowers`, `base44`, `wix`, `tinyfish` | General and vendor skill sets |

### Why it indexes instead of vendoring

Every entry is a git reference, not a copy. Nothing here holds anybody else's
source. Upstream fixes arrive on the next `/plugin marketplace update`, no
license question follows a copy into this repo, and each plugin stays owned by
the people who wrote it. It is the same rule the SQL catalog above states —
*the marketplace owns what exists, never the source* — applied to a file instead
of a table.

Entries track their repository's default branch. Add `"sha"` to a source to pin
one to an exact commit when a plugin needs to stop moving.

`chrome-devtools-mcp` is deliberately absent: it pulls the whole Chromium
`devtools-frontend` tree as git submodules, which fails behind a restricted
egress proxy and costs gigabytes anywhere else. `browser-use` covers the same
ground.

## Two decisions worth knowing

**The manifest is stored whole, and also normalised.** `product_versions.manifest`
is the jsonb source of truth, so a version is always reproducible and auditable.
The `declared_*` tables are derived from it at publish time so the catalog is
queryable — "which products want `menu.write`?" is a index scan, not a jsonb
crawl across every version.

**A product's channel points at exactly one current release.** The unique index is
keyed on `(product_id, channel)`, not on the version. Two versions of the same
product both claiming to be current stable is precisely the ambiguity this
prevents, and `releases` carries a denormalised `product_id` with a composite
foreign key back to `product_versions (id, product_id)` so it cannot drift from
the version's real product.

## Enforced, not documented

- slugs must be lowercase contract ids; versions must be semver
- a version cannot be published twice for one product
- a release cannot claim a product its version does not belong to
- surface kinds, capability and event directions are constrained enums
- a `free` product must carry no price, and a priced product must carry an
  amount and a currency

## Tests

```bash
createdb mk_test
TEST_DB=mk_test ./tests/run_tests.sh
```

15 cases, each asserting a specific rejection or success.

## License

Proprietary. See `LICENSE`.
