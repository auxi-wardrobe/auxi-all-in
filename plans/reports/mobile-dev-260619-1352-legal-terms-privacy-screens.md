# mobile-dev — In-app Terms of Service + Privacy Policy screens (B5 / B1)

**Branch:** `feat/legal-terms-privacy-screens` (off `main`, auxi submodule)
**Commit:** `792e6b47` feat(legal): add in-app Terms of Service + Privacy Policy screens
**Date:** 2026-06-19

Closes App Store blocker **B5** (legal docs reachable in-app); supports **B1**
(Privacy Policy disclosing AI third-party data sharing).

## Files created

- `auxi/src/content/legal/types.ts` — `LegalDocument` / `LegalSection` /
  `LegalDocumentType` typed structures. English-only-by-design note.
- `auxi/src/content/legal/terms-of-service.ts` — Terms body, **verbatim** from
  Figma node `3177:6642` (frame `3177:6809`), 18 sections, effective May 29 2026.
- `auxi/src/content/legal/privacy-policy.ts` — Privacy body from the draft
  (`plans/260619-1150-appstore-legal-docs/privacy-policy-draft.md`, §1–11 only;
  DRAFT banner + reviewer checklist skipped). Marked PENDING-CEO-APPROVAL +
  swappable in the file doc-comment; placeholders carried verbatim.
- `auxi/src/content/legal/index.ts` — barrel + `getLegalDocument(type)`.
- `auxi/src/screens/legal/LegalDocumentScreen.tsx` — one reusable screen
  (`documentType` param), canonical `<Header>` (ChevronLeft back + title) +
  safe-area `ScrollView` (`edges=['top','bottom']`), `ds.*` tokens only.
- `auxi/src/screens/legal/LegalSectionView.tsx` — small section renderer
  (heading / paragraphs / bullets) so the screen stays small.
- `auxi/src/screens/legal/legalLinkSegments.ts` — `buildLegalSegments()`,
  locale-agnostic splitter for the Welcome legal footer (matches on the
  localised link substrings, not a fixed English phrase).

## Files modified

- `auxi/src/types/navigation.ts` — `LegalDocument: LegalScreenParams` added to
  **both** `AuthStackParamList` (Welcome/unauth entry) and `AppStackParamList`
  (Settings/auth entry).
- `auxi/src/navigation/AuthNavigator.tsx` + `AppNavigator.tsx` — `LegalDocument`
  `<Stack.Screen>` registered in both stacks (two-place rule honoured per stack).
- `auxi/src/screens/auth/WelcomeScreen.tsx` — legal footer split so "Terms of
  Service" / "Privacy Policy" substrings are pressable `<Text>` spans
  (testIDs `welcome-legal-terms-link` / `welcome-legal-privacy-link`,
  `accessibilityRole="link"`), navigate to `LegalDocument` with `source:'welcome'`.
  Works across en/vi/fr.
- `auxi/src/screens/SettingsScreen.tsx` — dead no-op `your_information` row
  replaced with tappable **Terms of Service** + **Privacy Policy** rows
  (testIDs `settings-terms-of-service-row` / `settings-privacy-policy-row`),
  navigate with `source:'settings'`.
- `auxi/src/theme/theme.ts` — added `typography.aliases.poppinsBodyBold`
  (Poppins-Bold 16/24, tracking 0.15) for the legal title/headings — matches
  Figma `font-['Poppins:Bold']` 16px. No new colors (reused `ds.color.ink`
  #1d1f23 = Figma `text/neutral/base`, `ds.color.surface` #fcfcfd = Figma
  `background/primary/neutral_50`).
- `auxi/src/services/analytics.ts` — `trackLegalDocumentViewed(document, source)`
  helper (literal event name, bounded enum props, no PII).
- `auxi/src/translations/{en-EN,vi-VN,fr-FR}.json` — added
  `settings.terms_of_service` + `settings.privacy_policy` chrome labels;
  removed orphaned `settings.your_information` (no remaining code refs).
- `auxi/docs/analytics/mixpanel-tracking-plan.md` — §5.14 added for the event.

## Navigation approach

Two distinct stacks needed coverage: `AuthNavigator` (unauth — Welcome lives
here) and `AppNavigator` authed branch (Settings lives here). The same screen +
param shape (`LegalScreenParams`) is registered in both so both entry points
push the identical screen. The auth gate is untouched — pre-auth users can
reach legal docs from Welcome; authed users from Settings.

## Analytics

- Event `legal_document_viewed`, props `{ document: 'terms_of_service' |
  'privacy_policy', source: 'welcome' | 'settings' }`.
- Single fire site = `LegalDocumentScreen.tsx:60` mount effect (via
  `analytics.ts:237`). Press handlers in Welcome/Settings only navigate — no
  double-count. Bounded enums, no PII / URL / identifiers.

## Verification (Node 20)

- `npx tsc --noEmit` — **exit 0, clean** (no errors, incl. legacy).
- `yarn lint` — **no issues in any changed file**. Repo baseline residue
  (1 error in HomeScreen.tsx + 7 warnings in DatabaseScreen/OutfitCanvas/etc.)
  is all pre-existing in untouched files; I added zero.
- `./scripts/auxi-lint-tokens.sh` — **no violations in legal/content files**.
  (Script exits non-zero on 32 pre-existing baseline drifts in ItemDetail/
  Home/OutfitCanvas/ContextChipsModal/etc. — none mine.)
- Simulator: **NOT run** — cold-launch is blocked by the known Xcode-26.5 ↔
  RN-0.83.1 toolchain issue. Per task scope, static checks + clean compile are
  the bar; visual verification (qa-ui Compare + designer gate) is a later step.

## Open questions

- **Privacy body is a draft** — needs CEO/legal sign-off on wording, legal
  entity name, jurisdiction, contact email, effective date. The content module
  is intentionally swappable (single source of truth) — replace prose + flip
  `effectiveDate`, no screen changes.
- **Legal body localization** — kept English-only per task (legal decision,
  needs counsel). Chrome (titles/rows/links) IS localised. Flag if a localised
  legal body is later required.
- **Header chrome bg** — the canonical `<Header>` hardcodes `figmaBackground`
  (#f2efec) for its container; I set the back-button surface transparent and the
  screen body to `ds.color.surface` (#fcfcfd) to match Figma. The Header bar
  itself still sits on its warm tone — flag for the designer gate if the CEO
  wants the header bar on #fcfcfd too (would need a Header prop, out of scope).

**Status:** DONE
**Summary:** In-app Terms + Privacy screens built, reachable from Welcome
(unauth) and Settings (auth), ds-token-faithful, analytics + i18n + tracking-plan
wired; tsc/lint/token-lint clean for all changed files, committed to
`feat/legal-terms-privacy-screens`.
**Concerns/Blockers:** Privacy text is a pending-CEO-approval draft; simulator
visual verification deferred (toolchain blocker) → hand to qa-ui/designer.
