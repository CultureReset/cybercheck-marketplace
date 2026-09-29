> **Status: an earlier attempt, not part of Ghost.** Migrations and tests only,
> no service and no screen: the catalog (publishers, products, versions) for the
> earlier app-store design. That role is now `store_items` and `store_versions` in
> `gcr-api-clean`, which keeps this repo's app-manifest v1 shape for app versions.

---

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
