# PALETTE'S JOURNAL

## 2025-05-23 - Initialized Palette Journal
**Learning:** Palette agent starting work on Tesla Wrap Studio.
**Action:** Focus on micro-UX improvements in Flutter Web.

## 2025-05-23 - Loading States and Feedback for AI Actions
**Learning:** Primary actions that trigger long-running processes (like AI generation) require immediate visual feedback (loading indicators) and post-completion confirmation (SnackBars) to keep users informed and prevent redundant actions.
**Action:** Always implement `CircularProgressIndicator` inside buttons and provide success/error feedback via `SnackBar` for async operations.

## 2025-05-23 - Interactive Sidebars and Ink Effects in Flutter Web
**Learning:** For interactive sidebar elements in Flutter Web, using `InkWell` requires a `Material` ancestor (even a transparent one) to display ink splash/hover effects correctly. Always combine these with `Tooltip` and `Semantics` for accessibility.
**Action:** Wrap sidebar icons/labels with `Tooltip`, `Semantics`, and `InkWell`, ensuring a `Material(color: Colors.transparent)` parent is present.
