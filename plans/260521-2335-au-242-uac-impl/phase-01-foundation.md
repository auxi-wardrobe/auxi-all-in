# Phase 01 — Foundation (Theme, i18n, Secure Storage)

**Owner**: mobile-dev
**Priority**: P1 · **Status**: pending · **Effort**: 2d

## 1. Context Links

- Linear: https://linear.app/duncan-1/issue/AU-242
- Spec index: `plans/260521-2335-au-242-figma-spec/00-index.md` (Colors + Typography + Spacing tables)
- Gap analysis: `plans/reports/researcher-260521-2335-au-242-gap-analysis.md` §"Token / theme gap" + §"i18n gap" + L44-58 mobile infra table

## 2. Overview

Lay the design-token, font, locale, and secure-storage groundwork required by every subsequent UAC screen. No user-visible feature ships in this phase — it unblocks Phase 04.

## 3. Key Insights

- Existing theme has Poppins Regular/Medium and Playfair/Manrope/Archivo aliases — UAC needs additional Poppins Bold + SemiBold, Inter family, Roboto, and Noto Sans (vi diacritics fallback).
- `auxi/src/translations/index.ts:3` imports from `@/hooks/language/schema` but `auxi/src/hooks/` directory does not exist — **broken import that already prevents the bundle from compiling cleanly**. Must fix or remove before adding vi-VN.
- `auth.ts:47` currently stores access_token only via `Keychain.setGenericPassword('currentUser', access_token)`, drops refresh_token (TODO at L49). The `StoredTokenData` interface at `types/auth.ts:50-58` is already defined but unused — wire it.
- `figmaDestructive: '#bb251a'` already exists in theme — alias to `uacTextDangerBase`, don't add a duplicate hex.
- i18n is hard-coded `lng: 'en-EN'` at `translations/index.ts:23` — locale must be persisted to AsyncStorage so Language Settings screen (phase 04) can write through.

## 4. Requirements

### Functional
- Theme exports all 13 UAC color tokens, 9 typography styles, and named spacing constants used by spec.
- `vi-VN.json` resource registered alongside `en-EN.json` and `fr-FR.json`; `Language` type union includes `'vi-VN'`.
- Locale preference persists across app restarts (AsyncStorage).
- Token storage accepts `{ access_token, refresh_token, access_expires_at, refresh_expires_at, user_email }` and returns the same shape on read.
- One-time migration path: if old single-entry Keychain exists on app start, read it, write to new multi-key layout, delete old.

### Non-functional
- No regression on existing screens that read `theme.colors.primary/...` (additive only).
- Keychain operations stay async, do not block JS thread on cold start (>50ms is regression).
- `npx tsc --noEmit` clean.

## 5. Architecture

```
┌─ theme.ts ─────────────────────────────┐
│ colors: { ..., uac: { backgroundBase,  │
│   textBase, textDangerBase, ... } }    │
│ typography.aliases: { ..., uacH1Bold,  │
│   uacBodyMd, uacBodySmall, ... }       │
│ spacing.uac: { bodyPadding: 24,        │
│   buttonHeight: 56, fieldRadius: 8 }   │
└────────────────────────────────────────┘

┌─ services/auth.ts ─────────────────────┐
│ setTokens(StoredTokenData)             │
│ getAccessToken(): Promise<string|null> │
│ getRefreshToken(): Promise<string|null>│
│ getStoredTokens(): StoredTokenData|null│
│ clearTokens(): Promise<void>           │
│ migrateLegacyKeychain(): Promise<void> │ ← runs once on cold start
└────────────────────────────────────────┘

┌─ translations/ ────────────────────────┐
│ index.ts: i18n.init({ lng: persisted }) │
│ en-EN.json, vi-VN.json, fr-FR.json     │
│ locale-storage.ts: get/set via AsyncSt.│
└────────────────────────────────────────┘
```

Data flow on cold start:
`App.tsx → AuthContext.bootstrap() → migrateLegacyKeychain() → getStoredTokens() → if valid → setUser`

## 6. Related Code Files

### Modify
- `auxi/src/theme/theme.ts` — add UAC color tokens, typography styles, spacing constants
- `auxi/src/services/auth.ts` — refactor Keychain calls (lines 47, 49 TODO); export new helpers; remove duplicate `axios.create` (consolidate to `apiClient`)
- `auxi/src/translations/index.ts` — fix broken import; load persisted locale; register `vi-VN`
- `auxi/src/context/AuthContext.tsx` — wire `migrateLegacyKeychain()` into bootstrap
- `auxi/src/types/auth.ts` — verify `StoredTokenData` shape, export
- `auxi/package.json` — add font assets in `react-native.config.js`

### Create
- `auxi/src/translations/vi-VN.json` — skeleton mirroring `en-EN.json` keys + `boilerplate.uac.*` namespace stubs
- `auxi/src/translations/locale-storage.ts` — `getStoredLocale()`, `setStoredLocale(lang)` via AsyncStorage
- `auxi/src/hooks/language/schema.ts` **OR** rewrite `translations/index.ts:3` to drop the import (decide during implementation — schema file probably belongs but is missing)
- `auxi/src/assets/fonts/Poppins-Bold.ttf`, `Poppins-SemiBold.ttf`, `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`, `Roboto-Regular.ttf`, `NotoSans-Regular.ttf` (verify which are already vendored before downloading)

### Delete
None this phase.

## 7. Implementation Steps

1. Audit `auxi/src/assets/fonts/` — list existing TTFs. Identify the delta vs spec.
2. Download missing Poppins Bold/SemiBold, Inter family, Roboto, NotoSans into `assets/fonts/`. Update `react-native.config.js` `assets: ['./src/assets/fonts/']`. Run `npx react-native-asset`.
3. Resolve `translations/index.ts:3` broken import — either create `hooks/language/schema.ts` (defines `Language` type + `LANGUAGES` array including `vi-VN`) or move that type into `translations/types.ts` and update the import. Prefer the second (KISS).
4. Add UAC tokens to `theme.ts`:
   - Under `colors`: `uacBackgroundBase '#1d1f23'`, `uacBackgroundNeutral50 '#fcfcfd'`, `uacColorNeutral100 '#f2f4f7'`, `uacBorderBase '#1d1f23'`, `uacBorderBold200 '#7a7f89'`, `uacTextBase '#1d1f23'`, `uacTextSubtle100 '#40444d'`, `uacTextSubtle200 '#7a7f89'`, `uacTextPrimaryBase '#f2efec'`, `uacTextDangerBase '#bb251a'`, `uacTextInfoBase '#1465b4'`, `uacOnSurfaceVariant '#49454f'`.
   - Under `typography.aliases`: `uacH1Bold` (Poppins 700, 40/52), `uacH4Bold` (Poppins 700, 24/32), `uacBodyMdSemibold` (Inter 600, 16/24), `uacBodyMdMedium` (Poppins 500, 16/24), `uacBodyMdRegular` (Poppins 400, 16/24), `uacBodyXsRegular` (Inter 400, 12/16), `uacBodyXsMedium` (Inter 500, 12/16), `uacM3BodyLarge` (Poppins 400, 16/24), `uacM3BodySmall` (Roboto 400, 12/16, letterSpacing 0.4).
   - Under `spacing`: `uacBodyPadding 24`, `uacHeaderHeight 107`, `uacSafeAreaTop 112`, `uacSafeAreaBottom 12`, `uacButtonHeight 56`, `uacButtonRadius 16`, `uacFieldRadius 8`, `uacScreenRadius 18`.
5. Create `vi-VN.json` skeleton — copy `en-EN.json` structure verbatim, leave string values as English (flag with `// TODO_VI`) OR send to Viet for translation in parallel. Add `boilerplate.uac.*` namespace per gap analysis L156-168.
6. Create `locale-storage.ts` with `@react-native-async-storage/async-storage` (already a dep). Key: `@auxi/locale`.
7. Update `translations/index.ts`: on import, read persisted locale (async — wrap init in a function exported as `initI18n()` called from App.tsx). Default to device locale via `react-native-localize` → fallback `en-EN`.
8. Refactor `services/auth.ts`:
   - Remove standalone `axios.create` (lines 12-31). Replace all auth calls with `apiClient` from `services/apiClient.ts`.
   - Replace single `setGenericPassword('currentUser', ...)` with multi-key approach. Use `Keychain.setInternetCredentials(service, key, value)` for each of: `access_token`, `refresh_token`, `access_expires_at`, `refresh_expires_at`, `user_email`. Service constant: `AUXI_AUTH`.
   - Export: `setTokens(data: StoredTokenData)`, `getAccessToken()`, `getRefreshToken()`, `getStoredTokens()`, `clearTokens()`, `migrateLegacyKeychain()`.
   - `migrateLegacyKeychain()`: read `getGenericPassword('currentUser')`, if found → write to new format with `refresh_token=null`, expires fields = null, then `resetGenericPassword('currentUser')`. Idempotent.
9. Call `migrateLegacyKeychain()` once from `AuthContext.tsx` bootstrap before `checkAuth()`.
10. Run `npx tsc --noEmit` + `yarn lint` + cold-start the app on iOS sim. Verify no font warnings in Metro logs.

## 8. Todo List

- [ ] Audit existing `auxi/src/assets/fonts/` directory
- [ ] Download + link missing font files
- [ ] Fix broken import at `translations/index.ts:3`
- [ ] Add UAC color tokens to `theme.ts`
- [ ] Add UAC typography aliases to `theme.ts`
- [ ] Add UAC spacing constants to `theme.ts`
- [ ] Create `vi-VN.json` skeleton (en values as placeholder)
- [ ] Create `locale-storage.ts` (AsyncStorage wrapper)
- [ ] Refactor `translations/index.ts` to load persisted locale
- [ ] Refactor `services/auth.ts` to multi-key Keychain
- [ ] Add `migrateLegacyKeychain()` and wire to AuthContext bootstrap
- [ ] Remove standalone `axios.create` in `auth.ts`, consolidate to `apiClient`
- [ ] TypeScript + lint pass
- [ ] Cold-start sim verification (no font warnings, no crash on bootstrap)

## 9. Success Criteria

- `import { theme } from '@/theme/theme'` exposes all 13 UAC color tokens, 9 typography styles, 8 spacing constants — confirmed via TS autocomplete.
- `npx tsc --noEmit && yarn lint` exit 0.
- `vi-VN.json` loads when device locale is `vi`; user can toggle in dev via temporary debug menu (real switch ships in phase 04).
- On a device upgrading from old Keychain layout, user is NOT logged out — token migration runs transparently. Validated by manual test: log in on previous build → install this build → app still authenticated.
- New helpers (`setTokens`, `getStoredTokens`, etc.) covered by unit test in `services/__tests__/auth.test.ts`.

## 10. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Migration handler bug logs existing users out en-masse | Medium | High | Implement `migrateLegacyKeychain` as additive (write new keys before deleting old), test on simulator with manually planted legacy entry, ship behind try/catch that falls back to old read on failure |
| Font assets fail to link on iOS (Info.plist not updated) | Medium | Medium | After `react-native-asset` run, verify `Info.plist` UIAppFonts contains new entries; rebuild iOS pods (`cd ios && pod install`) |
| Hard-coded `lng: 'en-EN'` in production bundle until init refactor lands | Low | Low | Ship as initial value, then call `i18n.changeLanguage(persistedLocale)` once async storage resolves — single-frame flash acceptable for foundation phase |
| `hooks/language/schema.ts` route adds dead directory vs putting type in `translations/types.ts` | Low | Low | Pick path #2 (KISS) — fewer files |
| vi font diacritics fallback if NotoSans not loaded → unrendered glyphs | Medium | Medium | Validate with sample vi string in dev console; if iOS system fallback covers it, skip NotoSans for v1 |

## 11. Security Considerations

- Keychain entries scoped to `AUXI_AUTH` service; do **not** use `accessGroup` (no extension yet — OQ#29 parked).
- Migration path must not log token values (audit `console.log` in `auth.ts`).
- `vi-VN.json` is checked into git → no secrets, only UI copy. Same as `en-EN.json`.
- AsyncStorage stores **locale only**, not auth state. Tokens never touch AsyncStorage.

## 12. Next Steps

- Phase 02 (backend) can run in parallel — no dependency on this phase.
- Phase 03 depends on `services/auth.ts` consolidation landed here.
- Phase 04 depends on theme tokens + i18n vi-VN.

**Status**: pending
**Summary**: Token + font + locale + secure-storage groundwork. ~2 dev-days. Unblocks UI work.
**Concerns/Blockers**: `hooks/language/schema.ts` missing file — decision: move type to `translations/types.ts` (KISS). vi translation source from Viet not strictly blocking — ship en-as-placeholder.
