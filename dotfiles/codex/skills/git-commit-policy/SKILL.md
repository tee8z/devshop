---
name: git-commit-policy
description: Use whenever creating, amending, rewriting, or advising on Git commits. Enforces Conventional Commit messages and signed commits by default unless the user explicitly requests otherwise.
metadata:
  short-description: Conventional, signed Git commits
---

# Git Commit Policy

When making or amending commits:

- Use Conventional Commits: `type(scope): subject`.
- Prefer these types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- Use a scope when it adds useful context, for example `feat(nixos): add workstation module`.
- Keep the subject concise, imperative, and lower-case unless it contains a proper noun.
- Include a body only when it materially explains motivation, tradeoffs, or migration notes.
- Sign commits by default with `git commit -S` or `git commit --amend -S`.
- If signing fails, stop and report the signing problem instead of silently creating an unsigned commit.
- Do not stage unrelated work. Check `git status --short` first and stage only files needed for the requested change.

If the user explicitly asks for a different message style or an unsigned commit, follow that request and mention the deviation.

Keep this skill aligned with the repository-level `AGENTS.md` guidance in
Devshop.
