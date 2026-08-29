# The app manifest contract

`app-manifest.v1.json` is what a developer writes against. It is the only thing
the platform reads about an app — never its source, never its build output — so
this file is the whole public surface of "how do I build for this platform".

It lives here because the catalog is what decides what an app may declare. The
runtime in [`cybercheck-orchestrator`](../../cybercheck-orchestrator/platform/)
vendors a copy and fails its test suite if the two have drifted:

```bash
npm run sync:contract      # from the orchestrator checkout
```

## What the schema decides, and what it cannot

The schema decides **shape**: an id is publisher-prefixed and lowercase, a
version is semver, a surface path is relative so it cannot escape the app's own
origin, a free product carries no price and a priced one carries both halves.

It cannot decide **truth about a particular platform**. Whether
`contacts.read` is a permission that exists, whether a public surface remembered
to ask for `surface.public`, whether the id carries the publisher's own prefix —
those are checked at publish time by the runtime, against its own tables. A
manifest is valid here and still refused there, on purpose.

## Versioning

`schema_version` is `1` and is a `const`. A field may be added to v1 only if
every manifest that validated before still validates after. Anything else is
`app-manifest.v2.json` alongside this file, because a published version is
immutable and old manifests have to keep validating for as long as they are
installed anywhere.

## Two fields that carry more weight than they look

**`runtime.url`** pins the origin an app is served from. It is what the platform
binds a handoff code to and what the iframe host checks `event.origin` against,
so changing it in a new version is a security-relevant change, not a cosmetic
one.

**`data.tables.<name>.public`** decides what an anonymous visitor on a public
surface may do with a table. It defaults to `none`. A public form that writes
has to say `append`, and `append` does not imply read — that is what stops a
public request form from handing a stranger the list of everyone else's
requests.
