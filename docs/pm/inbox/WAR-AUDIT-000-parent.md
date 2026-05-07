---
id: WAR-AUDIT-000
type: epic
title: "Figma audit `470:1121` — gaps & follow-ups"
state: Backlog
priority: P1
labels: [audit, figma, area:mobile, area:backend]
assignee: null
parent: null
created: 2026-05-05
source: docs/pm/inbox (Linear MCP unavailable in session)
---

## Context

Full Figma audit of page `✅ Hifi-design (RFD)` (nodeId `470:1121`) against
`auxi/` codebase, completed 2026-05-05. Audit method: Figma Plugin API
node-tree extraction + sticky-note text reading. No screenshots.

Audit doc: `auxi/docs/FIGMA_AUDIT_470-1121.md`

This epic tracks every gap or partial implementation surfaced by the audit.
Designer (CEO) will assign priority + ownership per sub-issue.

## Scope summary

- **6 CRITICAL** — designer-required, missing in code (sub-issues 001–006)
- **6 WARNING** — partial / unverified (sub-issues 007–012)
- **INFO** — confirmed alignments, captured below as notes; no separate tickets

## CRITICAL sub-issues (P1/High)

| ID | Title |
|---|---|
| WAR-AUDIT-001 | [Home] Add 3 modes selector (Safe / Power / Creative) |
| WAR-AUDIT-002 | [Home] Add Pin feature — pin item then mix |
| WAR-AUDIT-003 | [Home] Auto-open "find more context" after 3 unsuccessful swipes |
| WAR-AUDIT-004 | [Onboarding/Home] Add mood-check screens (Light/Sharp, Energy) |
| WAR-AUDIT-005 | [Backend/Mobile] Auto-remove background on item upload |
| WAR-AUDIT-006 | [Favorites] Add Love-collection screen (list of liked outfits) |

## WARNING sub-issues (P2/Medium)

| ID | Title |
|---|---|
| WAR-AUDIT-007 | [Onboarding] Resolve dual onboarding flow (gender variants vs single shared) |
| WAR-AUDIT-008 | [Splash] Implement flash-screen / splash flow (9 Figma frames) |
| WAR-AUDIT-009 | [Wardrobe] Verify wardrobe sort by latest |
| WAR-AUDIT-010 | [Items] Verify AI auto-tag for material / price |
| WAR-AUDIT-011 | [Home] Add download-AI-photo action |
| WAR-AUDIT-012 | [Home] Differentiate 3 AI loading state variants |

## INFO — confirmed alignments (no ticket)

- Sections explicitly excluded from MVP are correctly absent in code: mix
  tool (`1917:9591`), AI beauty, full setting, import flow, mood-check
  sub-section under "NOT in MVP".
- 6/24 sticky notes are template-only (`1064:1110`, `1064:1848`, `1064:2440`,
  `1774:8086`, `1777:11256`) — designer left them blank. Safe to ignore.
- Tag-edit fields match Figma exactly: `'category' | 'color' | 'fit' | 'style'`
  in `auxi/src/screens/ItemDetailScreen.tsx:40` ↔ Type / Color / Fit / Style.
- System-item edit-permission rule (note `909:7801`): `STYLE_TAG_LESS_USED`
  exists in `wardrobeService.ts:8`; full UI rule "cannot edit/delete common
  items" not verified end-to-end — captured in WAR-AUDIT-009 verification.

## Acceptance criteria (epic-level)

- [ ] All 12 sub-issues triaged by designer (assigned, scoped, or rejected).
- [ ] CRITICAL items have a product decision (in-MVP / deferred / dropped)
      before mobile-dev picks up implementation work.
- [ ] Backend-side items (WAR-AUDIT-005, 009, 010) verified against
      `wardrobe-backend/` — verification comments posted on each.
- [ ] Audit doc `FIGMA_AUDIT_470-1121.md` re-reviewed once all sub-issues
      close, to confirm no drift introduced.

## Dependencies

- Designer (CEO) decision on: 3 modes scope, pin feature scope, mood-check
  placement, dual-onboarding resolution.
- Backend audit pass for `wardrobe-backend/` (out of scope of original
  Figma audit).

## Out of scope

- Sections marked "DO NOT BUILD IN MVP" in Figma (mix tool, AI beauty,
  full setting, import flow).
- Future-MIX-tool section (`1917:9591`).

## Hand-off

Designer triages each sub-issue → routes to `mobile-dev` or `backend-dev`
via tech-lead.
