# AUTOMATIONS.md

These prompts are written for Codex automations in the FinanceCategorizer repo.
Adapt the cadence and scope to the specific task you want to watch.

## 1) Weekly architecture drift review

**Title**
Review architecture drift

**Prompt**
Review the FinanceCategorizer repo for architecture drift. Focus on whether business logic is leaking into SwiftUI views, whether shared logic belongs in `Shared/` rather than `Platform/`, and whether AI-related code still preserves guarded availability and deterministic fallbacks. Summarize findings with concrete file paths and suggest the smallest safe refactors.

## 2) Daily changed-files quality pass

**Title**
Audit recent Swift changes

**Prompt**
Inspect the most recent Swift changes in FinanceCategorizer. Flag risky edits in import flows, categorization, review queue behavior, Foundation Models guards, localization, or XcodeGen configuration. Prefer concise findings with file paths, risk level, and the next best verification command.

## 3) Weekly UI polish backlog

**Title**
Find UI polish opportunities

**Prompt**
Review the macOS and iOS SwiftUI screens in FinanceCategorizer and identify the highest-value UI polish opportunities. Focus on hierarchy, spacing, readability, table-heavy screens, empty/loading/error states, localization quality, and glass-style presentation. Return a short prioritized backlog with concrete files and why each item matters.

## 4) Import pipeline regression review

**Title**
Check import pipeline regressions

**Prompt**
Audit the FinanceCategorizer import pipeline for likely regressions. Focus on preview rows, manual header mapping, diagnostics, invalid-row reporting, summary counts, recent imports refresh, and review-queue handoff. Summarize findings with file paths and suggested validation commands.

## 5) AI fallback safety review

**Title**
Verify AI fallbacks

**Prompt**
Inspect FinanceCategorizer AI-related code and verify that Foundation Models usage remains guarded, conservative, and optional. Check availability gating, deterministic fallback summaries, fallback categorization suggestions, and confidence-to-review behavior. Return only concrete findings with affected files and recommended fixes.

## 6) Localization hygiene check

**Title**
Check localization coverage

**Prompt**
Review the repo for new or changed user-facing strings that may have missed localization. Focus on iOS and macOS screens, shared design-system components, AI prompts, and any language-aware formatting logic. Report only concrete gaps with file paths and the least disruptive fix.

## 7) Validation follow-up

**Title**
Suggest next validation

**Prompt**
After a code change in FinanceCategorizer, suggest the smallest useful validation command set based on the files that changed. Prefer XcodeGen when project files changed, iOS builds for shared or iOS UI changes, macOS builds for shared or macOS UI changes, and targeted tests when behavior changed.
