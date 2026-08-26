---
name: ste-system-docs
description: Create or revise Markdown that explains software systems, architecture, operations, runbooks, troubleshooting, or debugging. Apply ASD-STE100-inspired controlled English and use Mermaid when relationships, sequences, states, or decisions are easier to see than read. Do not use for ordinary prose or code-only tasks.
metadata:
  short-description: Clear system docs with STE and Mermaid
---

# STE System Documentation

Write accurate technical documentation that readers can scan and use. Prefer a
small visual to a long explanation when the visual makes the system behavior
materially easier to understand.

## Establish The Facts

- Inspect the applicable source code, configuration, logs, tests, and existing
  documentation before you describe the system.
- Separate verified behavior from a hypothesis or an unknown condition.
- Preserve commands, code, identifiers, paths, API names, and established
  project terms exactly.
- Use one term for each concept. Do not replace an established technical term
  with a synonym only for variety.
- Do not invent components, data flows, signals, failure causes, or recovery
  steps to complete a diagram.

## Apply STE Principles

Use ASD-STE100 Simplified Technical English principles for the prose:

- Use the active voice. Use the passive voice only when the agent is unknown
  and an active sentence would change the technical meaning.
- Keep a descriptive sentence at or below 25 words.
- Keep a procedural sentence at or below 20 words.
- Put only one topic in each descriptive sentence.
- Put only one instruction in each procedural sentence, unless two actions must
  occur at the same time.
- Start an instruction with an imperative verb. Put a necessary condition
  before the action.
- Give information gradually. Keep one topic in each paragraph and use no more
  than six sentences in a paragraph.
- Prefer simple, concrete words. Avoid vague pronouns, idioms, rhetorical
  language, and unnecessary synonyms.
- Define an abbreviation at its first use. Use the same abbreviation after the
  definition.
- Use vertical lists when a sentence contains many items or actions.
- Identify a real risk with `WARNING` or `CAUTION`. State the required action
  and the possible result.

Project-specific nouns and verbs are valid technical terms. Do not simplify a
term if the change makes it inaccurate. Do not claim formal ASD-STE100
compliance unless you checked the complete applicable standard and controlled
dictionary. Otherwise, describe the result as STE-informed when a label is
necessary. The [official ASD-STE100 website](https://www.asd-ste100.org/) is the
primary reference.

## Show The System

Use the smallest visual that makes an important relationship clear:

- Use a Mermaid `flowchart` for components, data flow, dependencies, or a
  diagnostic decision tree.
- Use a Mermaid `sequenceDiagram` for a request, event, protocol, or debugging
  trace across participants.
- Use a Mermaid `stateDiagram-v2` for lifecycle states and transitions.
- Use a Mermaid `erDiagram` for important data relationships.
- Use a Markdown table for exact mappings or compact comparisons.

Put Mermaid source in a fenced `mermaid` block. Use syntax that renders in
GitHub and the built-in VS Code Markdown preview. Keep labels short. Use the
same component names in prose, diagrams, and code references. Label important
edges and conditions. Split a dense chart into focused charts.

Do not repeat a diagram in prose. After the diagram, explain only the important
conclusion, constraint, or next action. For troubleshooting, base each branch
on an observable signal. End each branch with a corrective action, a verified
healthy state, or an escalation point.

## Build The Markdown

Lead with the document purpose or the operational outcome. Select only the
sections that help the reader, such as architecture, data flow, dependencies,
operations, observability, failure modes, and troubleshooting. Do not force a
fixed template onto a small document.

Use language identifiers on code fences. Give expected results after diagnostic
commands. Distinguish a command from its output. Link to authoritative local
files and external references when they support a technical claim.

## Check The Result

Before delivery:

- Verify each technical claim against the available evidence.
- Check terminology, sentence length, active voice, and instruction order.
- Check that each visual answers a question that prose would answer less well.
- Render or validate Mermaid with repository tooling when it is available.
- Confirm that commands are safe, scoped, and consistent with the user's task.
