# Decision record template

Copy the block below into `NNNN-kebab-title.md`, taking the next unused number from the [index](README.md), and add a
row to the index. Numbers are never reused, including for rejected decisions. `status` is one of `proposed`,
`accepted`, `rejected`, `deprecated` or `superseded`.

````markdown
---
title: Short, decision-first title
date: YYYY-MM-DD
status: proposed
deciders: ["@handle"]
supersedes: []
---

# NNNN — Short, decision-first title

## Context

The forces in tension, and the evidence: issues, requirement IDs, other decisions.

## Decision

One unambiguous claim, stated as "We will ..." or as an imperative.

## Consequences

### Positive

- ...

### Negative

- ...

### Neutral

- ...

## Enforcement

The requirement ID, check or CI job that fails when the decision is broken, or `review-only` and what a reviewer
looks for.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A | ... | rejected: ... |
| B | ... | **chosen** |

## References

- ...
````
