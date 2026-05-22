# Phase 03 — Service Layer + API Doc Contract

**Owner**: backend-dev (API doc) + mobile-dev (client) — joint contract sync
**Priority**: P1 · **Status**: pending · **Effort**: 1d

## 1. Context Links

- Linear: https://linear.app/duncan-1/issue/AU-242
- Gap analysis: `plans/reports/researcher-260521-2335-au-242-gap-analysis.md` §"Contract changes between auxi ↔ wardrobe-backend" + Mobile services table
- Umbrella `CLAUDE.md` §"Two-Repo Contract" — API_DOCUMENTATION.md is the contract; tech-lead sign-off required

## 2. Overview

Bridge backend (phase 02) and mobile screens (phase 04) with a typed client layer and an updated API contract. **tech-lead must sign off on the API doc diff before phase 04 starts** — this is the umbrella's drift-prevention checkpoint.

## 3. Key Insights

- Per umbrella `CLAUDE.md`, `API_DOCUMENTATION.md` is the canonical contract — no shared SDK, no codegen. Sync discipline is the only thing keeping mobile and backend in lockstep.
- Existing `auxi/src/services/auth.ts` has 7 functions (login, register, updateUser, etc.) plus a **duplicate** `axios.create` (consolidated in phase 01). New phase adds 8 functions matching the new endpoints.
- TanStack Query 5 is the established async-state lib in `auxi/` (per `auxi/CLAUDE.md`). Each endpoint gets a typed mutation hook.
- `AuthContext.tsx` auto-logs-in after register at L80-85 — **must remove** because new flow is signup → verify-email → home, not signup → home.

## 4. Requirements

### Functional
- `wardrobe-backend/API_DOCUMENTATION.md` documents all 9 new endpoints + 2 modified endpoints with: HTTP method, path, request schema, response schema (success + each error code), rate limits, auth requirement.
- Mobile client functions (8 new) exposed from `auxi/src/services/authService.ts` (split from `auth.ts` if size exceeds 200 lines per dev-rules).
- Each function has a corresponding TanStack Query mutation hook in `auxi/src/hooks/auth/` (e.g. `useVerifyEmailMutation`, `useForgotPasswordMutation`).
- Error mapping: every endpoint's known error codes map to a typed `AuthError` discriminated union (`network_error`, `validation_error`, `account_exists`, `invalid_credentials`, `expired_token`, `invalid_token`, `email_not_verified`, `rate_limited`).
- TypeScript types match Pydantic schemas 1:1.
- `AuthContext.tsx` extended with: `verifyEmail`, `resendVerification`, `requestPasswordReset`, `resetPassword`, `pendingEmail` state (carried email between screens 3 → 4/9/7).
- Auto-login-after-register removed.

### Non-functional
- `npx tsc --noEmit` clean on auxi.
- `pytest` green on backend (no change).
- API doc readable by a contributor opening for the first time.

## 5. Architecture

```
┌─ API_DOCUMENTATION.md ────────────┐
│ Source of truth (tech-lead signs) │
└────────────┬──────────────────────┘
             │ (typed by hand on both sides)
   ┌─────────┴─────────┐
   ↓                   ↓
backend Pydantic    auxi TS types
schemas/auth.py     services/auth-types.ts (NEW)
```

Mobile data flow:
```
Screen
  → hooks/auth/useXxxMutation.ts  (TanStack mutation)
    → services/authService.ts     (raw apiClient call)
      → apiClient.ts              (axios + interceptors)
        → backend
      ← 401 → refresh interceptor → retry once → bubble up
```

`AuthContext` exposes `pendingEmail` state so screen 3 (email input) writes it, screen 4 (password create) reads it, screen 6 (verify) reads it. Reset via `setPendingEmail(null)` on flow completion.

## 6. Related Code Files

### Modify
- `wardrobe-backend/API_DOCUMENTATION.md` — add 9 new endpoint sections + modify register/login sections; document rate limits + error codes
- `auxi/src/services/auth.ts` — currently 7 functions. Either extend OR split into `authService.ts` (new) if file exceeds 200 lines. Prefer split (KISS).
- `auxi/src/services/apiClient.ts` — add 401 → refresh → retry interceptor
- `auxi/src/context/AuthContext.tsx` — add new methods + `pendingEmail`; remove auto-login on register (L80-85)
- `auxi/src/types/auth.ts` — extend `AuthError` union, add `AccountByEmailResponse`, `VerifyEmailResponse`, etc.

### Create
- `auxi/src/services/authService.ts` (if split from auth.ts) — 8 new client functions
- `auxi/src/services/auth-types.ts` — TS types matching backend schemas
- `auxi/src/hooks/auth/use-verify-email-mutation.ts`
- `auxi/src/hooks/auth/use-resend-verification-mutation.ts`
- `auxi/src/hooks/auth/use-forgot-password-mutation.ts`
- `auxi/src/hooks/auth/use-reset-password-mutation.ts`
- `auxi/src/hooks/auth/use-refresh-mutation.ts`
- `auxi/src/hooks/auth/use-logout-mutation.ts`
- `auxi/src/hooks/auth/use-account-by-email-query.ts` (conditional on OQ#26 — if route dropped, this hook + screen 7 also drop)
- `auxi/src/services/__tests__/authService.test.ts` — unit test happy path + each error variant

### Delete
None this phase.

## 7. Implementation Steps

1. **Backend doc**: open `wardrobe-backend/API_DOCUMENTATION.md`. For each new endpoint (9), add section with:
   - `### POST /api/auth/verify-email`
   - **Auth**: none (token in body)
   - **Rate limit**: 10/min/IP
   - **Request**: JSON schema
   - **Response 200**: schema
   - **Response 410**: `{ code: 'expired_token' }`
   - **Response 404**: `{ code: 'invalid_token' }`
   - Repeat for all 9.
2. Modify existing register section: note `verification_required: true` field added; remove "returns access_token" from success response.
3. Modify existing login section: document 403 `{ code: 'email_not_verified', email }` variant.
4. Send doc diff to tech-lead for review. **DO NOT proceed to step 5 until sign-off.** Per umbrella rules: "Tech-lead reviews the diff and signs off on contract changes."
5. **Mobile types**: create `auth-types.ts` mirroring backend schemas. Types: `VerifyEmailRequest/Response`, `ResendVerificationRequest`, `ForgotPasswordRequest`, `ResetPasswordRequest`, `RefreshRequest/Response`, `GoogleSignInRequest/Response`, `AppleSignInRequest/Response`, `AccountByEmailResponse`. Extend `AuthError` discriminated union.
6. **Client functions**: in `authService.ts`, add typed wrappers — each one is a thin call to `apiClient.post/get` with typed params + return.
7. **TanStack mutations**: one file per endpoint under `auxi/src/hooks/auth/`. Pattern:
   ```ts
   export const useVerifyEmailMutation = () =>
     useMutation({
       mutationFn: (req: VerifyEmailRequest) => authService.verifyEmail(req),
       onError: mapApiError,
     });
   ```
8. **Refresh interceptor**: in `apiClient.ts`, add axios response interceptor: if 401 and request was not `/auth/refresh` and we have a refresh token → call `/auth/refresh` → on success update Keychain via `setTokens()` → retry original request once; on failure → call `clearTokens()` + `AuthContext.logout()`.
9. **AuthContext**: add `pendingEmail: string | null`, `setPendingEmail(email)`, `clearPendingFlow()`. Add `verifyEmail(token)`, `resendVerification()`, `requestPasswordReset(email)`, `resetPassword(token, newPwd)`. Remove auto-login at L80-85; replace with `setPendingEmail(email)` + navigation to VerifyEmail screen (phase 04 wires the navigation; here we just expose the state).
10. **Error mapping**: implement `mapApiError(err: AxiosError): AuthError` — switch on status + `data.code` → return typed union member. Used by every mutation's `onError`.
11. **Unit test**: mock `apiClient` and assert each authService function builds correct URL + body, and `mapApiError` produces correct discriminated value for each documented error.
12. Run `npx tsc --noEmit` + `yarn test`.

## 8. Todo List

- [ ] Draft `API_DOCUMENTATION.md` updates (9 new endpoints + 2 modifications)
- [ ] Submit doc diff to tech-lead → wait for sign-off
- [ ] Create `auxi/src/services/auth-types.ts`
- [ ] Create `auxi/src/services/authService.ts` (or extend existing auth.ts)
- [ ] Add 8 client functions matching endpoints
- [ ] Create 8 TanStack mutation/query hooks under `hooks/auth/`
- [ ] Add 401 → refresh → retry interceptor to `apiClient.ts`
- [ ] Extend `AuthContext.tsx` with new methods + `pendingEmail`
- [ ] Remove auto-login at `AuthContext.tsx:80-85`
- [ ] Implement `mapApiError` + extend `AuthError` union
- [ ] Unit test client functions + error mapping
- [ ] `npx tsc --noEmit && yarn test` pass

## 9. Success Criteria

- API_DOCUMENTATION.md diff has tech-lead's explicit approval (comment or commit ack).
- For every endpoint in phase 02, there is a typed client function + mutation hook + at least one unit test.
- `mapApiError` produces a typed `AuthError` for every documented HTTP error code per endpoint.
- 401 from a non-refresh route triggers one refresh attempt + retry (validated by mocked interceptor test).
- `AuthContext` after register does NOT call login — instead exposes `pendingEmail` for downstream screens.
- `npx tsc --noEmit && yarn lint && yarn test` exit 0.

## 10. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| API doc diverges from backend implementation (typo in field name) | High | High | Use the doc as the source of truth — backend tests should reference the schema names in doc; tech-lead reviews diff against actual code |
| TS types drift from Pydantic over time | Medium | Medium | Manual review at each contract change is the umbrella's policy; future work: consider codegen via `openapi-typescript` |
| Refresh-token interceptor loops forever on broken refresh endpoint | Low | High | Guard: never retry `/auth/refresh` itself; max 1 retry per original request; on second 401 → logout |
| `AuthContext` removal of auto-login breaks any currently-deployed mobile build | Low | Low | Gated by `UAC_V2_ENABLED` flag; legacy path keeps auto-login |
| `pendingEmail` state lost on app background → return to flow | Medium | Medium | Persist `pendingEmail` to AsyncStorage (small string, non-sensitive); restore on context bootstrap |

## 11. Security Considerations

- Refresh token MUST be sent in body, not header (some proxies log auth headers).
- `pendingEmail` is non-sensitive (user knows their own email); safe in AsyncStorage.
- 401 → refresh flow must not include the access token in the refresh request (use Keychain refresh token only).
- Logout mutation must clear Keychain BEFORE navigating away (race condition: navigating first could allow next screen to read stale tokens).
- `mapApiError` must not leak server error messages directly to UI for unknown errors — coerce to `network_error` for unmapped codes.

## 12. Next Steps

- Phase 04 starts the moment this phase merges + tech-lead has signed off on the doc.
- Phase 05 OAuth client functions added in `authService.ts` here (signatures only — implementation in phase 05).

**Status**: pending
**Summary**: Contract sync + typed client + 401 refresh interceptor. ~1 dev-day if both devs are available; gated on tech-lead API-doc sign-off.
**Concerns/Blockers**: tech-lead availability for review is the only external dependency.
