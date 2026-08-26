# Vendored from xai-org/grok-build-plugin-cc

Upstream: https://github.com/xai-org/grok-build-plugin-cc
Commit:   92b76a670713335229644e94add15ab40c80e547
Path:     plugins/grok-build
License:  Apache 2.0 (LICENSE and NOTICE copied alongside)
Changes:  none — verbatim copy

## Why this one is copied and the rest are not

Everything else in `.claude-plugin/marketplace.json` is a git reference. This
plugin is the one we intend to build on rather than merely use, so we hold a
copy we can change without waiting on anyone.

## Refreshing it

    git clone --depth 1 https://github.com/xai-org/grok-build-plugin-cc /tmp/gbp
    rm -rf external_plugins/grok-build
    cp -r /tmp/gbp/plugins/grok-build external_plugins/grok-build
    cp /tmp/gbp/LICENSE /tmp/gbp/NOTICE external_plugins/grok-build/

Then update the commit above. If this copy has been modified, diff it against
upstream first — Apache 2.0 requires stating changes, and this file is where
they go.

## It needs the CLI

The plugin shells out to the `grok` binary; it does nothing on its own.

    curl -fsSL https://x.ai/cli/install.sh | bash   # macOS / Linux
    grok login                                      # or: export XAI_API_KEY=xai-...

`grok login --device-auth` covers headless hosts with no browser. Source for the
CLI is at https://github.com/xai-org/grok-build, also Apache 2.0.

## Verifying this copy

Upstream's tests live in the repo root, not in the plugin, so run them against
a scratch tree:

    git clone --depth 1 https://github.com/xai-org/grok-build-plugin-cc /tmp/gbp
    mkdir -p /tmp/vtest/plugins
    cp -r /tmp/gbp/tests /tmp/gbp/package.json /tmp/vtest/
    cp -r external_plugins/grok-build /tmp/vtest/plugins/grok-build
    cd /tmp/vtest && env -u CLAUDE_PLUGIN_DATA node --test tests/*.test.mjs

60 of 64 pass. The four that do not are testing xAI's repository scaffolding
rather than the plugin, and cannot pass against a plugin-only copy:

| Test | Wants |
|---|---|
| `bump-version updates every release manifest` | `scripts/bump-version.mjs` |
| `bump-version check mode reports stale metadata` | `scripts/bump-version.mjs` |
| `repo manifests are in sync at 0.2.1` | the repo-root `marketplace.json` |
| `plugin surfaces use /grok-build names` | the repo-root `README.md` |

`env -u CLAUDE_PLUGIN_DATA` is load-bearing. One upstream test asserts the
state directory falls back to `os.tmpdir()`, but does not clear
`CLAUDE_PLUGIN_DATA` first — so it fails whenever the suite is run from inside
a live Claude Code session, which sets that variable.
