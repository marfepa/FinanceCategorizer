---
name: apple-liquid-glass-ui-polish
description: Use this skill when adapting a SwiftUI iOS/macOS app to Apple's Liquid Glass aesthetic, especially for floating top bars, search bars, segmented controls, inspectors, cards, dashboards, side panels, and transitions between selection states. Use it for both visual treatment and motion design. Do not use it for unrelated business logic, data models, or backend changes.
---

# Apple Liquid Glass UI Polish

## Goal

Bring SwiftUI surfaces and controls closer to Apple's Liquid Glass design language without turning the whole app into a blur-heavy mockup. The result should feel native, selective, layered, adaptive, and fluid.

This skill is optimized for FinanceCategorizer, which already uses:
- SwiftUI on iOS and macOS
- dashboards, cards, tables, inspectors, floating controls, and segmented filters
- app-specific wrappers like `glassCard()`, `glassHeroCard()`, `AppMaterials`, `AppColors`, `AppSpacing`, and `AppRadius`

## Core design rules

1. **Use Liquid Glass selectively.**
   Prioritize elements that sit above content or control context:
   - floating top bars
   - segmented range selectors
   - search bars
   - inspectors and side panels
   - quick action clusters
   - compact chips and badges
   - hero utility surfaces that need emphasis

   Avoid covering every card, every table row, or long scrolling content areas with heavy glass.

2. **Preserve content legibility first.**
   Data-dense finance views must remain scannable. Glass is an accent and hierarchy tool, not a replacement for structure.

3. **Prefer one prominent glass layer over many competing layers.**
   If a screen already has a floating glass bar, reduce glass intensity elsewhere.

4. **Motion should feel absorbed, not snapped.**
   Prefer spring-based movement, geometry continuity, morphing between shapes, and soft hover/press response over abrupt state changes.

5. **Use Apple-native APIs first.**
   Reach for `glassEffect`, `GlassEffectContainer`, and `glassEffectID` before inventing custom blur stacks. Use fallback wrappers only when platform availability requires it.

## Apple guidance to follow

Base all Liquid Glass work on Apple's current guidance:
- `glassEffect(_:in:)` for custom Liquid Glass surfaces
- `GlassEffectContainer` to combine related glass shapes and enable morphing
- `glassEffectID(_:in:)` to tell the system which controls should morph between states
- interactive glass behavior for controls that should react to user input
- apply the effect sparingly and primarily to controls, navigation, and emphasis layers

See the references in `references/` before making changes.

## Repository-specific targets

When working in this repository, focus first on these files and patterns:

### App shell and navigation
- `Apps/macOS/MacAppRootView.swift`
- toolbar items and section switching

### Screens that benefit most from Liquid Glass
- `Platform/macOSUI/Screens/MacDashboardView.swift`
- `Platform/macOSUI/Screens/MacInsightsView.swift`
- `Platform/macOSUI/Screens/MacTransactionsView.swift`
- `Platform/macOSUI/Screens/MacImportsView.swift`
- `Platform/macOSUI/Screens/MacReviewQueueView.swift`
- `Platform/macOSUI/Screens/MacCategoriesView.swift`
- `Platform/macOSUI/Screens/MacSettingsView.swift`

### High-value components to polish
- `Platform/macOSUI/Components/TransactionTable.swift`
- `Platform/macOSUI/Components/TransactionInspectorView.swift`
- `Platform/macOSUI/Components/ImportDropZone.swift`
- `Platform/macOSUI/Components/ImportSummarySheet.swift`
- `Platform/macOSUI/Components/RecentImportsList.swift`
- `Platform/macOSUI/Components/RuleEditorSheet.swift`

### Existing styling hooks to reuse instead of bypassing
- `glassCard()`
- `glassHeroCard()`
- `AppMaterials`
- `AppColors`
- `AppSpacing`
- `AppRadius`

## Workflow

### 1) Audit before changing

Before editing, identify:
- which surfaces are primary controls versus dense content containers
- where the app already uses custom glass wrappers
- where the UI currently feels flat, heavy, or too segmented
- where animation is currently binary instead of fluid

Write down the specific interaction layers on that screen:
- navigation layer
- control layer
- content layer
- inspection layer
- transient/feedback layer

### 2) Decide what should actually be glass

Use this hierarchy:

**Best candidates**
- floating segmented selectors
- floating search bars
- top filter bars
- inspector shells
- compact KPI cards
- quick action buttons
- overlay summaries
- import drop zones that need affordance

**Usually not full-glass**
- dense tables with many rows
- long forms
- large scrollable report bodies
- every dashboard card at once

When in doubt, make the control chrome glassy and keep the content body cleaner.

### 3) Group related elements inside a container

When several related glass elements must animate together, wrap them in `GlassEffectContainer`.

Use this especially for:
- top bars with a movable active segment
- chip groups
- grouped floating controls
- expanding or collapsing filter controls
- inspectors with a main shell and internal highlighted control

### 4) Morph active controls instead of swapping them bluntly

For segmented selectors, tabs, or toggle groups:
- maintain a stable overall container
- create one active glass capsule that moves between options
- connect source and destination with `glassEffectID`
- prefer spring motion with a slightly damped response
- keep inactive options lighter and less elevated

The active element should feel like it slides and re-forms, not like a new pill fades in on top.

### 5) Add restrained microinteractions

Allowed motion patterns:
- hover lift on macOS: very small scale and elevation changes
- press compression: subtle, not rubbery
- selection morph: spring with continuity
- reveal or hide of bars or inspectors: slide + fade, not large bouncy moves
- drag target emphasis: surface thickens or brightens slightly

Avoid:
- large scale jumps
- long blur animations
- multiple simultaneous symbol, opacity, scale, and offset effects fighting each other
- jelly-like motion on data-heavy screens

## Implementation patterns

### Floating top bar

Use when a screen has range filters, search, segmented modes, or key contextual actions.

Requirements:
- visually detached from the scrolled content
- aligned to the content grid
- translucent or glass-treated shell
- subtle border or highlight for edge definition
- content scrolls beneath or independently from the bar when appropriate

Recommended structure:
- outer shell: glass surface
- inner active segment: morphing glass highlight
- labels/icons: crisp and high-contrast

### Search bar

Requirements:
- should feel like a floating utility control, not a flat form field
- keep typing area stable and readable
- use glass on the shell, not excessive inner blur
- search icon and placeholder should remain subdued but clear

### Segmented control or range picker

Requirements:
- one shared rounded shell
- one active moving capsule
- use `GlassEffectContainer`
- use `glassEffectID` to morph active selection
- inactive labels remain readable without competing emphasis

### Cards and hero panels

Requirements:
- use glass only on high-level summary cards or hero surfaces
- maintain strong internal spacing and typography
- never rely on glass alone for hierarchy; use layout and type scale too
- if a hero card is glassy, subordinate cards should usually be quieter

### Inspector or side panel

Requirements:
- should read as a translucent utility layer above the main workspace
- use a slightly denser shell than central content
- section dividers and local controls can be lighter glass or neutral material
- keep forms readable; do not make every field highly glossy

### Drop zones and import summaries

Requirements:
- drag target should strengthen slightly on hover or targeted state
- use a continuous surface transition rather than just changing border color
- preserve clear affordance with border, icon, and spacing

## Animation guidance

Use motion that matches Liquid Glass principles:

### Good defaults
- hover: `.easeOut(duration: 0.18)` or a light spring
- selection morph: spring-based
- panel reveal: medium spring or eased move + opacity
- number changes: `contentTransition(.numericText())` where relevant
- symbol swaps: `contentTransition(.symbolEffect(.replace))` when appropriate

### Spring suggestions
Tune by feel, but these are sensible starting points:
- selector capsule: `spring(response: 0.32, dampingFraction: 0.82)`
- hover lift: `spring(response: 0.22, dampingFraction: 0.86)`
- panel reveal: `spring(response: 0.30, dampingFraction: 0.88)`
- drag target emphasis: `spring(response: 0.25, dampingFraction: 0.80)`

Do not apply the same spring to every interaction blindly.

## Code preferences

1. Prefer small reusable view modifiers and wrappers over repeating material stacks.
2. If the repo already has helpers like `glassCard()`, evolve those helpers before adding parallel styling systems.
3. Gate Apple-only APIs with availability checks when necessary.
4. Keep fallback styling acceptable on systems where the full API is unavailable.
5. Keep diffs localized. Do not refactor unrelated screen logic while polishing visuals.

## Expected output when this skill is used

When implementing a change, produce:
1. a short audit of which surfaces should become Liquid Glass and which should not
2. the exact files or components to edit
3. the visual hierarchy decision
4. the animation plan
5. the code changes
6. a quick verification checklist

## Review checklist

- Is glass limited to the right layers?
- Do dense tables and analytics remain readable?
- Are transitions continuous and morphing where appropriate?
- Are Apple-native APIs used before custom blur stacks?
- Do the changes fit the existing finance app visual language?

Before finishing, verify:
- The screen has a clearer hierarchy than before.
- Glass is concentrated on controls, emphasis surfaces, or overlays.
- Dense content is still readable at a glance.
- Selected states morph or transition fluidly.
- Hover, press, and selection states feel native on macOS.
- There is no overuse of blur, opacity, or shadows.
- The result feels closer to Apple system UI, not a generic frosted-glass mockup.
- Existing project styling helpers remain coherent.

## Done means

A change is complete only when:
- the chosen screen or component clearly looks more native to Apple’s Liquid Glass direction
- motion is smoother and more continuous, especially in segmented controls and floating bars
- the result improves hierarchy without hurting readability
- the code remains reusable and consistent with the repository’s design system

## Anti-patterns

Do not:
- apply heavy blur to entire scrolling views
- turn every card into the same glossy slab
- add strong drop shadows everywhere
- use oversized scale animations on finance or productivity UIs
- mix several competing materials on one screen without hierarchy
- replace native controls unnecessarily when a small wrapper or modifier will do
- claim Liquid Glass while implementing only blur and opacity

## Good prompt examples

- Adapt the top range selector in `MacInsightsView.swift` so it feels like a floating Liquid Glass control with a morphing active segment.
- Refactor `TransactionTable.swift` and its search area so the search bar becomes a floating glass utility bar while the table remains readable.
- Polish `MacReviewQueueView.swift` so the header, segmented filter, and inspector shell use Liquid Glass selectively with native-feeling hover and selection motion.
- Upgrade `ImportDropZone.swift` to feel like an Apple-style Liquid Glass drop target with refined targeted-state animation.
