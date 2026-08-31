---
name: ste-system-docs
description: Use for Markdown system documentation, architecture, operations, runbooks, troubleshooting, or debugging. Apply STE-informed prose and faithful visuals. Excludes ordinary prose and code-only work.
metadata:
  short-description: Clear system docs with STE and faithful visuals
---

# STE System Documentation

Write accurate, usable technical documentation.

## Establish The Facts

- Inspect applicable code, configuration, logs, tests, and documentation.
- Separate verified behavior from hypotheses and unknowns.
- Preserve commands, identifiers, paths, API names, and project terms exactly.
- Use one term per concept. Do not invent facts or relationships.

## Apply STE Principles

Use ASD-STE100-inspired principles:

- Prefer active voice. Use passive voice only when the agent is unknown and
  active voice changes the meaning.
- Limit descriptive sentences to 25 words and procedural sentences to 20.
- Keep one topic per descriptive sentence and one instruction per procedural
  sentence, except simultaneous actions.
- Put conditions first; start instructions with imperative verbs.
- Use single-topic paragraphs of at most six sentences. Prefer simple concrete
  words and lists for many items. Avoid vague pronouns, idioms, and decorative
  synonyms.
- Define an abbreviation once, then use it consistently.
- Reserve `WARNING` and `CAUTION` for real risks. State the required action and
  possible result.

Project-specific nouns and verbs are valid technical terms. Do not simplify a
term inaccurately. Call the result STE-informed, not ASD-STE100-compliant,
unless the complete standard and controlled dictionary were checked. Use the
[official ASD-STE100 website](https://www.asd-ste100.org/) as the primary
reference.

## Show The System

Use the smallest faithful visual:

- Mermaid `flowchart`: components, dependencies, data flow, or decisions.
- Mermaid `sequenceDiagram`: ordered messages among participants.
- Mermaid state or data diagram: only when native semantics match the facts.
- ASCII: irregular topology, nesting, layers, file trees, layouts, or
  terminal-safe output.
- Table: exact mappings or compact comparisons.
- Prose or a list: when a visual adds no clarity.

Never alter relationships to fit a diagram. Use consistent component names and
label important edges or conditions. Keep Mermaid compatible with GitHub and
VS Code. Fence ASCII as `text`, use spaces and portable characters, and check
monospaced alignment. Do not restate the entire visual in prose.

For troubleshooting, branch on observable signals. End each branch with a
corrective action, verified healthy state, or escalation point.

## Build The Markdown

Lead with the purpose or operational outcome. Add only useful sections. Use
language identifiers on fences, distinguish commands from output, and give
expected diagnostic results. Link authoritative sources for technical claims.

## Check The Result

Before delivery:

- Verify claims, terminology, sentence limits, voice, and instruction order.
- Confirm each visual is faithful and materially clearer than prose.
- Validate Mermaid when possible and inspect ASCII in a monospaced view.
- Confirm commands are safe, scoped, and consistent with the task.
