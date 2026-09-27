---
title: "iOS Code Review Checklist"
date: 2026-04-12
summary: "What to look for when reviewing a pull request in an iOS codebase, ordered from highest to lowest impact."
keywords: ["Code Review", "Concurrency", "Accessibility"]
---

Review in order of impact. Don't spend the reviewer's attention on naming while a data race sits two lines down.

## 1. Correctness

- Does the change do what the pull request says? Is there a test proving it?
- Are error paths handled (`throws`, empty states, offline networking)?
- Any force unwraps or `try!` on data that comes from outside the app?

## 2. Concurrency and lifetime

- UI updates happen on the `@MainActor`.
- New `Task { }` blocks: who cancels them? Do they capture `self` strongly beyond the screen's lifetime?
- Shared mutable state crossing isolation domains is `Sendable` or protected by an actor.
- Stored closures use `[weak self]` where needed — no retain cycle.

## 3. User-facing quality

- Accessibility: meaningful `accessibilityLabel`s, works with Dynamic Type and VoiceOver.
- Localization: no hard-coded user-facing strings; plurals use String Catalog variants.
- Layout survives small screens, landscape, and the largest text size.

## 4. Architecture

- New code follows the module's existing pattern (MVVM, coordinators, dependency injection style).
- Dependencies point inward; a feature module doesn't import another feature module.

## 5. Tests

- Unit tests cover new logic; UI tests only for critical flows.
- Tests are deterministic — no real network, no sleeping, clocks and dates injected.

## 6. Style

Leave style to the linter. If you must comment, prefix with `nit:` so the author knows it's optional.
