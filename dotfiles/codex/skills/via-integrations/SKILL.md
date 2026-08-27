---
name: via-integrations
description: Use when the user references a Linear URL, Linear issue, team, project, or asks to create, read, update, search, or comment on Linear issues. Use the `via` command line tool as the proxy for configured third-party services; Linear is available through `via linear api`.
metadata:
  short-description: Access Linear through via
---

# Via Integrations

Use `via` for configured third-party service access. For Linear, do not bypass
`via` with direct API tokens or ad hoc credential handling.

## Linear

Use the configured Linear capability:

```sh
via linear api POST /graphql --json '{"query":"{ viewer { id name } }"}'
```

Expected authentication smoke-test shape:

```json
{"data":{"viewer":{"id":"<connection-id>","name":"via connection"}}}
```

For non-trivial GraphQL requests, prefer a temporary JSON payload file and
`--json @/tmp/file.json` to avoid fragile shell quoting.

When the user provides a Linear link:

- Extract the issue identifier or URL from the link.
- Query Linear through `via linear api POST /graphql`.
- Resolve IDs from Linear rather than guessing.

When the user asks to create a Linear issue:

- Ask only for missing required product details, such as title, team, project, or description.
- Resolve the target team/project IDs through Linear GraphQL.
- Create the issue through `via linear api POST /graphql` using the `issueCreate` mutation.
- Return the created issue identifier and URL.

Useful local references:

- `$HOME/repos/via/README.md`
- `$HOME/repos/via/docs/linear-oauth-setup.md`
- `$HOME/repos/via/examples/linear.toml`

Setup checks, when Linear access fails:

```sh
via login
via config doctor linear
via capabilities
```

Do not paste OAuth tokens, client secrets, refresh tokens, or other secret
material into prompts, issue comments, logs, or terminal output.
