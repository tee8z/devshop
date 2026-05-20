# AI Agent Instructions

## Git Commits

When creating, amending, rewriting, or advising on commits:

- Use Conventional Commits: `type(scope): subject`.
- Prefer these types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- Use a scope when it adds useful context, for example `feat(nixos): add workstation module`.
- Keep the subject concise, imperative, and lower-case unless it contains a proper noun.
- Include a body only when it materially explains motivation, tradeoffs, or migration notes.
- Sign commits by default with the user's configured signing key.
- If signing fails, stop and report the signing problem instead of silently creating an unsigned commit.
- Do not stage unrelated work. Check `git status --short` first and stage only files needed for the requested change.

If the user explicitly asks for a different message style or an unsigned commit, follow that request and mention the deviation.

## Repository Safety

- Keep secrets, host-specific credentials, generated hardware identifiers, and workplace-specific project names out of this repo.
- Prefer placeholders and documented customization points for machine-specific values.
