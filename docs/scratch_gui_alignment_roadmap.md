# Scratch GUI Alignment Roadmap

This document tracks the remaining work after Phase 2 of the staged `scratch-gui` alignment.

## Current baseline

- Phase 1 completed:
  `flow_detail` resolution was moved behind `ScratchInspectorWeb.FlowDetailViewModel`.
- Phase 2 completed:
  parser output now includes explicit detail-display block data via `detail_header` and `detail_blocks`.

## Phase 3

Goal: replace the current detail panel with a `scratch-gui`-style block stack view while keeping behavior stable.

Tasks:
- Rework the Flow detail panel to render from `detail_script.header` and `detail_script.blocks` only.
- Introduce clearer visual separation for hat blocks, stack blocks, cap blocks, and C-shaped blocks.
- Improve slot rendering for literal inputs versus nested reporter blocks.
- Use the new `fields`, `inputs`, and `children` data instead of relying mainly on `label`, `parts`, and `branches`.
- Keep the current `broadcast` detail panel unchanged unless it blocks the new script/custom-block detail UI.
- Verify that long scripts remain scrollable and readable in the current LiveView layout.

Done when:
- Script detail no longer depends on the legacy `render_blocks` shape.
- Script stacks are readable as block structures rather than label lists.

## Phase 4

Goal: expand the new detail UI to custom blocks and broadcast-driven navigation.

Tasks:
- Render custom block definitions using `detail_header` plus `detail_blocks`.
- Show custom block argument information from `mutation`, `fields`, and `inputs`.
- Decide whether broadcast detail stays as a receiver list or gets a `scratch-gui`-style preview.
- Ensure clicking a broadcast receiver moves focus to the target sprite and the correct detail block stack.
- Revisit the `flow_select_detail` payload if extra identifiers are needed for robust navigation.
- Verify JS and LiveView event contracts together when changing Flow interactions.

Done when:
- Script and custom-block detail views use the same rendering model.
- Broadcast-to-detail navigation is stable and predictable.

## Phase 5

Goal: tune the visual fidelity and interaction quality of the new block UI.

Tasks:
- Refine category colors, spacing, corners, shadows, and nesting treatment to better match Scratch.
- Differentiate round, boolean, and menu-like input slots more clearly.
- Improve the visual treatment of C-block interiors and multi-branch structures.
- Review narrow viewport behavior and overflow handling.
- Reduce visual jitter when changing sprites, tabs, and selected flow details.
- Consolidate repeated styling into clearer helpers or CSS structure if the template becomes too dense.

Done when:
- The detail panel feels visually consistent with Scratch-style blocks.
- The UI remains readable on desktop and narrow layouts.

## Phase 6

Goal: clean up selection state and event contracts around the new detail model.

Tasks:
- Reassess the `flow_detail` shape after the new detail renderer settles.
- Clarify how `selected_sprite`, `selected_target_type`, and `flow_detail` interact.
- Decide close/reselect behavior for detail panels and keep it consistent across node types.
- Ensure Mermaid node selection and detail panel state stay synchronized.
- Leave room for future extensions such as block-level selection or code-to-block jumping.

Done when:
- Flow selection state is explicitly defined and not spread across ad hoc conditions.
- Mermaid and LiveView stay in sync without special-case patches.

## Phase 7

Goal: add regression protection for the new detail pipeline.

Tasks:
- Extend parser tests for nested inputs, C-block children, and custom-block details.
- Extend ViewModel tests for script, custom-block, and broadcast cases using the new shape.
- Add fixture-based checks against representative `.sb3` samples.
- Define a lightweight verification checklist for Flow interactions and detail transitions.
- Freeze fallback behavior for unsupported or partially parsed blocks in tests.

Done when:
- Regressions in detail shape or rendering are detectable without manual inspection alone.

## Notes for implementers

- Prefer evolving `detail_header` and `detail_blocks` over introducing a second competing detail shape.
- Treat `render_blocks` as legacy compatibility data and avoid expanding its role further.
- When changing Flow detail behavior, review:
  - `lib/scratch_inspector/parser.ex`
  - `lib/scratch_inspector_web/live/flow_detail_view_model.ex`
  - `lib/scratch_inspector_web/live/inspector_live.ex`
  - `assets/js/mermaid_hook.js`
