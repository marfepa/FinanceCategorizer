# AGENTS.md

## Project

FinanceCategorizer is a multiplatform Swift app scaffold generated with XcodeGen.

This repository lives in `FinanceCategorizer/` and the generated Xcode project is `FinanceCategorizer/FinanceCategorizer.xcodeproj`.

### Core facts

- App name: `Finance Categorizer`
- Bundle ID prefix: `com.mariofernandez`
- Deployment targets: iOS 17.0, macOS 26.0
- Swift version: 5.10
- Package dependency: `ZIPFoundation` from GitHub
- Main config file: `project.yml`
- Setup notes: `SETUP_XCODE.md`

### Generated targets

- `FinanceCategorizerIOS`
- `FinanceCategorizerMac`
- `FinanceCategorizerTests`
- `FinanceCategorizerUITestsIOS`
- `FinanceCategorizerUITestsMac`

### Entry points

- iOS app entry: `Apps/iOS/FinanceCategorizerIOSApp.swift`
- iOS root view: `Apps/iOS/IOSAppRootView.swift`
- macOS app entry: `Apps/macOS/FinanceCategorizerMacApp.swift`
- macOS root view: `Apps/macOS/MacAppRootView.swift`

## Repository layout

Follow these boundaries unless a task explicitly requires a refactor:

- `Apps/`
  - app entry points and scene wiring only
- `Shared/`
  - domain models, repositories, services, AI, persistence, view models, shared UI, and reusable logic
- `Platform/`
  - platform-specific SwiftUI screens and components
- `Resources/`
  - assets, localization, fonts, and preview resources
- `Tests/`
  - unit tests and UI tests
- `scratch/`
  - local experiments, throwaway scripts, and temporary analysis that should not be wired into the app

## What this app already is

The scaffold is not a generic template. It is built around:

- local financial categorization and import workflows
- SwiftData persistence with an `AppContainer`
- shared business logic in `Shared/`
- separate iOS and macOS UI layers
- import, categorization, review queue, rules, dashboard, insights, settings, and AI features

## Architecture rules

- Keep business logic out of SwiftUI views when possible.
- Prefer view models, repositories, and services for non-trivial logic.
- Reuse shared code from `Shared/` instead of duplicating logic across platforms.
- Do not move macOS-specific UI into `Shared/` just to reuse a small view.
- Keep changes scoped. Do not mix import pipeline, AI, dashboard, and UI polish work in one change unless required.

## Data and persistence

The app uses SwiftData and a repository layer.

When touching data flow:

- preserve `AppContainer` as the composition root
- keep `ModelContainerFactory` and `FinanceSchema` consistent
- keep repositories in `Shared/Data/Repositories`
- keep DTOs in `Shared/Data/DTO`
- keep domain models in `Shared/Domain/Models`

## Import and categorization rules

When touching import or categorization flows:

- do not break CSV/XLSX/PDF import affordances already exposed in the macOS UI
- preserve the preview -> diagnostics -> import -> summary flow
- keep review-queue support explicit for low-confidence or ambiguous cases
- avoid hiding important diagnostics behind silent failures
- prefer additive changes over broad rewrites

### Current business rules worth preserving

- auto-categorization threshold: `0.92`
- soft auto-categorization threshold: `0.80`
- suggestion threshold: `0.65`
- max AI suggestions: `3`
- minimum local-model examples to train: `5`
- minimum local-model examples for ready state: `24`
- minimum ready categories: `3`
- minimum examples per ready category: `4`
- default currency: `EUR`

## AI / Foundation Models rules

This repo already uses a guarded Foundation Models pattern.

When touching AI-related code:

- preserve deterministic fallback behavior
- keep `#if canImport(FoundationModels)` guards intact
- keep availability checks for `macOS 26.0` and `iOS 26.0`
- do not make Foundation Models the only execution path
- keep non-AI behavior useful when AI is unavailable or disabled
- prefer narrow prompts and structured outputs over long free-form prompts

If you change AI categorization or summaries:

- verify that unavailable-model paths still return safe fallback values
- do not claim certainty where the code uses confidence thresholds
- keep categorization conservative for ambiguous transactions
- ensure prompts respect the user language and the app language model

## UI rules

The app is aiming for a polished Apple-native aesthetic with a shared design system.

When modifying SwiftUI screens:

- preserve existing navigation structure
- keep visual hierarchy strong and spacing consistent
- prefer small focused components over oversized monolithic views
- avoid embedding heavy business logic in view bodies
- use existing design primitives where available:
  - `AppSpacing`
  - `AppTypography`
  - `AppMaterials`
  - `AppColors`
  - `AppRadius`
  - `GlassCard`
  - `PrimaryButton`
  - `SearchBar`
  - `LoadingView`
  - `EmptyStateView`
  - `ErrorStateView`

### Platform-specific UI

- iOS UI lives in `Platform/iOSUI`
- macOS UI lives in `Platform/macOSUI`
- keep platform-specific affordances in their respective folders
- prefer native patterns such as `TabView` on iOS and `NavigationSplitView` on macOS when appropriate

### Repo-local skill mapping

Use the matching repo-local skill instead of repeating long instructions inline:

- `swift-feature-scaffold` for small scoped feature work
- `swift-bugfix-triage` for localized bug fixes
- `swift-ui-polish` for SwiftUI visual and usability polish
- `swift-ai-guarded` for Foundation Models, prompts, fallback, and structured output work

When a task is about making SwiftUI screens feel more native to Apple's current design language, especially with floating bars, segmented controls, inspectors, cards, or motion polish, use `swift-ui-polish` unless the task is specifically about AI behavior.

## Localization and language

The app supports Spanish and English.

When touching language-aware code:

- localize new UI strings
- use `AppLanguage` helpers rather than hardcoding ternaries in text-generation paths
- inject the locale at the app root rather than scattering locale overrides through the app
- keep dynamic text generation language-aware in AI and insight services

## Validation workflow

Before finishing a change, prefer this order:

1. Regenerate the project if `project.yml` changed:
   ```bash
   xcodegen generate
   ```
2. Build iOS when iOS or shared code changed:
   ```bash
   xcodebuild -scheme FinanceCategorizerIOS -destination 'platform=iOS Simulator,name=iPhone 17' build
   ```
3. Build macOS when macOS or shared code changed:
   ```bash
   xcodebuild -scheme FinanceCategorizerMac build
   ```
4. Run focused tests when relevant:
   ```bash
   xcodebuild test -scheme FinanceCategorizerIOS -destination 'platform=iOS Simulator,name=iPhone 17'
   ```

If a requested change is too large to validate fully, state clearly what was and was not verified.

## Safe change strategy

For non-trivial tasks:

- inspect the affected files first
- make the smallest coherent change that solves the task
- verify compile-sensitive edits
- summarize changed files and remaining risks

Avoid:

- speculative rewrites
- renaming many symbols without need
- changing project structure unless the task explicitly asks for it
- mixing unrelated cleanups into the same patch

## Definition of done

A task is only done when all of the following are true:

- the requested behavior is implemented
- architecture boundaries are respected
- existing guarded AI fallback paths are preserved
- the changed code is internally consistent
- relevant build/test commands were run, or skipped with a clear reason
- the final summary lists touched files, validation performed, and any follow-up risks

## Good prompts for this repo

Examples of requests that should trigger focused work:

- “Add a new macOS budget insights card without changing repositories.”
- “Fix the import preview when Openbank headers are partially mapped.”
- “Refactor the AI summary service to keep deterministic fallback intact.”
- “Polish the review queue UI without changing categorization logic.”
- “Add a shared formatter in `Shared/` and wire it into macOS views.”

## Existing support files

- `README.md` explains the current scaffold, structure, and startup flow.
- `SETUP_XCODE.md` explains how to build the scaffold manually in Xcode.
- `Resources/README.md` documents where assets and localization files should go.
- `Tests/README.md` documents the test target split.

Use the skill whose job most closely matches the request instead of repeating long instructions in-thread.
