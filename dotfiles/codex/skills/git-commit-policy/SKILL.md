---
name: git-commit-policy
description: Use for Git commit creation, amendment, rewriting, or advice. Require Conventional Commits and signatures unless the user opts out.
metadata:
  short-description: Conventional, signed Git commits
---

# Git Commit Policy

When creating or revising commits:

- Inspect `git status --short`. Stage only task files; exclude unrelated changes
  and secret material.
- Use `type(scope): imperative subject`. Include a scope only when useful. Keep
  the subject concise and lower-case, except for proper nouns.
- Prefer `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`,
  `ci`, `chore`, or `revert`.
- Add a body only for material motivation, tradeoffs, or migration notes.
- Sign with `git commit -S` or `git commit --amend -S`.
- If signing fails, stop and report the signing problem instead of silently creating an unsigned commit.

Honor an explicit request for another message style or an unsigned commit, and
state the deviation.
