---
name: github-stacked-prs
description: Plan and manage large features as formally linked GitHub stacked pull requests. Use when planning or implementing a feature that may need multiple dependent review layers, or when creating, linking, reviewing, rebasing, or preparing a GitHub PR stack; do not use for one independent PR or unrelated changes that can land in any order.
metadata:
  short-description: Build reviewable GitHub PR stacks
---

# GitHub Stacked Pull Requests

Use a formal GitHub stack when a feature has two or more dependent layers that
are meaningful to review separately. Prefer one pull request (PR) when the work
is cohesive and reviewable. Use independent PRs against the trunk when changes
can land in any order.

Planning a stack does not authorize remote pushes, PR changes, review requests,
rebases, or merges. Confirm that the user's request permits each external
mutation before you perform it.

## Model The Stack

Create one branch and one PR for each layer:

```text
trunk <- branch-1 / PR 1 <- branch-2 / PR 2 <- branch-3 / PR 3
```

The bottom PR targets the trunk. Each higher PR targets the branch directly
below it. All branches must be in the same repository.

Do not put all layers on one head branch. Do not retarget every layer to the
trunk. Both choices replace focused layer diffs with cumulative diffs.

Order layers by dependency. Put shared contracts and foundations below their
consumers. Choose boundaries that remain useful without prescribing fixed
categories for every feature.

Each layer must have a clear purpose, focused tests, and a reviewable diff. A
layer can depend on lower layers, but it must not depend on a higher layer.

Prefer creating the stack before implementation when the dependencies are
clear. If useful boundaries emerge during implementation, a temporary
integration branch or draft PR is acceptable. Split it into coherent layers
before human review. Do not rewrite shared history without authorization.

When work already exists on one branch, inspect its publication state and
commit boundaries before splitting it:

- If existing commits match the layers, create stack branches at those commit
  boundaries.
- If unpublished commits need restructuring, rewrite them only when the user
  authorized history changes and the original state is recoverable.
- If the branch is shared, preserve its history. Ask whether to construct new
  layer branches or keep one PR when clean boundaries do not exist.

Do not move unrelated user changes or duplicate the same change across layers.

## Create A New Stack

Verify that `gh stack` is available before you start. Use the GitHub website if
the extension is unavailable and the user did not authorize its installation.

Initialize the bottom layer against the selected trunk:

```sh
gh stack init --base <trunk> <bottom-branch>
```

Commit the layer, then add each higher branch:

```sh
gh stack add <next-branch>
```

Submit the complete stack when the layers are ready:

```sh
gh stack submit
```

Use `--open` only when every selected PR is ready for review. Non-interactive
or `--auto` submission creates drafts by default unless `--open` is present.

## Link Existing Pull Requests

First, verify that the branch history is linear. Confirm that each PR base is
the head branch of the layer below it.

Link existing PRs from bottom to top:

```sh
gh stack link --base <trunk> --open <bottom-pr> <middle-pr> <top-pr>
```

Omit `--open` when any PR must remain a draft. A chain of ordinary dependent
PRs is not a formal GitHub stack until GitHub stack metadata confirms it.

`gh stack link` creates remote stack metadata but no local tracking. If future
local stack operations are required, adopt the branches from bottom to top:

```sh
gh stack init --base <trunk> <bottom-branch> <middle-branch> <top-branch>
gh stack submit
```

## Review And Iterate

Describe each PR's position and dependency in its body. Link the feature issue
to each PR when the user requests issue tracking.

Before requesting human review:

- inspect each isolated layer and the complete stack;
- run focused tests for each layer and full-stack checks at the top;
- address unresolved review comments in the layer that owns the concern;
- cascade lower-layer changes through every higher branch;
- verify assignments, requested reviewers, and CI on all PRs.

If a review finding is already implemented in a higher layer, explain that
stack boundary with exact evidence. Do not duplicate or reorder code only to
silence a layer-local review tool.

After a rebase, inspect every unresolved review conversation again. Do not
dismiss a finding only because GitHub marks its location as outdated. Fix each
still-valid concern or reply with evidence before resolving its thread.

Documentation in an early layer must not claim that a later implementation is
deployed. Final documentation must describe the complete shipped behavior.

## Keep The Stack Current

When the trunk advances, rebase the complete stack instead of updating only one
branch:

```sh
gh stack rebase
gh stack push
```

Run the rebase with a clean worktree. Resolve conflicts in their owning layer,
then continue with `gh stack rebase --continue`. Use `gh stack rebase --abort`
when safe resolution is uncertain.

If signed commits are required, use the local CLI rebase. GitHub's server-side
stack rebase creates unsigned commits. Before rebasing, confirm that local Git
signing is configured for rewritten commits. After rebasing, inspect the full
trunk-to-top range:

```sh
git log --format='%h %G? %s' <trunk>..<top-branch>
```

Do not push if a required signature is absent, invalid, or from an unexpected
signer. Stop and report the signing problem.

`gh stack push` uses force-with-lease and is not atomic. If one branch fails,
inspect every remote head before retrying.

## Verify The Remote Result

Confirm these invariants after create, link, rebase, or push operations:

- the stack trunk is correct;
- GitHub reports non-null stack metadata;
- PR order is bottom-to-top and complete;
- every PR has the intended base and head branch;
- branch history is linear;
- rewritten commits retain required signatures;
- assignments, reviewers, comments, and checks remain correct.

Use `gh stack view` only for a locally tracked stack. For a remotely linked
stack, inspect the GitHub stack map or the GitHub API.

## Merge Boundary

Do not merge without explicit authorization. When authorized, use the formal
stack merge workflow instead of merging an intermediate PR into its feature
branch:

```sh
gh stack merge <stack-number>
```

Before merging, confirm that every included PR has its required approvals and
checks. Confirm the requested merge method and the intended highest layer.

GitHub stacked pull requests are in public preview. Verify command behavior
against current `gh stack --help` and the
[official GitHub documentation](https://docs.github.com/en/pull-requests/reference/stacked-pull-requests)
when the installed extension or GitHub interface differs from this skill.
