---
name: via-integrations
description: Use for Linear API URLs, issues, teams, projects, reads, searches, comments, or mutations. Access services through `via`; use `via linear api` for Linear.
metadata:
  short-description: Access Linear through via
---

# Via Integrations

Use `via` as the proxy for configured services. Never bypass it with direct API
tokens or ad hoc credentials.

Send GraphQL through the configured capability:

```sh
via linear api POST /graphql --json '{"query":"{ viewer { id name } }"}'
```

For links, extract the identifier and query Linear. Resolve entity IDs instead
of guessing. For issue creation, ask only for missing required details, resolve
team and project IDs, use `issueCreate`, and return the issue identifier and URL.

For non-trivial requests, use a temporary JSON payload with `--json @<file>` to
avoid fragile shell quoting.

If access fails, diagnose with:

```sh
via login
via config doctor linear
via capabilities
```

Never expose OAuth tokens, client secrets, refresh tokens, or other secrets in
prompts, comments, logs, or terminal output.
