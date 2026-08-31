---
name: github-stacked-prs
description: "Use for dependent GitHub PR stacks or features needing layered review: plan, create, link, review, rebase, or merge. Excludes single or independent PRs."
metadata:
  short-description: Build reviewable GitHub PR stacks
---

# GitHub Stacked Pull Requests

Use a formal stack for two or more dependent, separately reviewable layers. Use
one pull request (PR) for cohesive work. Use independent PRs when changes can
land in any order. Planning does not authorize remote changes, history rewrites,
review requests, or merges.

## Preserve The Model

```text
trunk <- branch-1 / PR 1 <- branch-2 / PR 2 <- branch-3 / PR 3
```

The bottom PR targets the trunk. Each higher PR targets the branch below it.
Keep all branches in one repository with linear history. Put foundations below
consumers. Give each layer one purpose, focused tests, and no dependency on a
higher layer. Never duplicate a change across layers or include unrelated work.

Inspect existing commits and publication state before splitting work. Reuse
coherent commit boundaries. Rewrite only unpublished, recoverable history with
authorization; preserve shared history. If shared work lacks clean boundaries,
ask whether to create new layer branches or keep one PR. A temporary integration
branch or draft is acceptable while boundaries emerge; split it before review.

## Create Or Link

Check `gh stack --help` before mutations because stacked PRs are in public
preview. If the command is unavailable, use GitHub's website unless installation
is authorized.

Create the bottom branch, commit each layer before adding the next, then submit:

```sh
gh stack init --base <trunk> <bottom-branch>
gh stack add <next-branch>
gh stack submit
```

Use `--open` only when every submitted PR is review-ready; otherwise submit
drafts.

Link existing PRs bottom-to-top after verifying their bases and linear history:

```sh
gh stack link --base <trunk> --open <bottom-pr> <middle-pr> <top-pr>
```

Omit `--open` when any linked PR must remain a draft. Linking creates remote
metadata, not local tracking. For later local operations, adopt bottom-to-top,
then submit:

```sh
gh stack init --base <trunk> <bottom-branch> <middle-branch> <top-branch>
gh stack submit
```

## Review And Update

State each PR's stack position and dependency. Inspect and test every isolated
layer plus the full stack. Put fixes in the owning layer and cascade lower-layer
changes upward. Do not duplicate a fix that intentionally belongs above the
reviewed layer. Recheck unresolved conversations after rebases, including
outdated locations. Early documentation must not claim later behavior is
deployed.

## Keep The Stack Current

Use a clean worktree and update the complete stack:

```sh
gh stack rebase
gh stack push
```

Resolve conflicts in their owning layer. Continue with
`gh stack rebase --continue`; abort when safe resolution is uncertain.

If signed commits are required, use the local CLI rebase. GitHub's server-side
rebase creates unsigned commits. Confirm local signing first, then inspect the
rewritten range:

```sh
git log --format='%h %G? %s' <trunk>..<top-branch>
```

Stop before pushing if a required signature is absent, invalid, or unexpected.
`gh stack push` uses force-with-lease and is not atomic; inspect every remote
head after a partial failure.

## Verify The Remote Result

After mutations, verify the trunk, stack metadata, PR order, bases and heads,
linear history, required signatures, reviews, comments, and checks. Use
`gh stack view` only for locally tracked stacks; inspect GitHub for remote-only
links.

Do not merge without explicit authorization. When authorized, use the formal
stack workflow after confirming approvals, checks, merge method, and highest
included layer:

```sh
gh stack merge <stack-number>
```

When command behavior differs, consult the
[official GitHub documentation](https://docs.github.com/en/pull-requests/reference/stacked-pull-requests)
and preserve these invariants.
