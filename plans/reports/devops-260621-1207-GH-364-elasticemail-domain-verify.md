# devops — GH-364 ElasticEmail sending-domain verification

**Date:** 2026-06-21
**Owner:** devops
**Goal:** Make ElasticEmail deliver transactional mail (email-verify + password-reset) for the Auxi backend, sending as an authenticated `noreply@` sender (fix the Gmail DMARC/SPF bounce).

## Status: BLOCKED on external DNS

Account-side registration is DONE. The exact DNS records are determined and ready. The blocker is that **auxi.app DNS is hosted on a third-party provider I cannot write to** — the records must be added manually by whoever controls that DNS, then I finish verification + delivery re-test.

---

## Diagnosis (re-confirmed)

- **ElasticEmail account** `duc2820@gmail.com` — Active. `validdomaincount: 0` → had NO verified sending domain (`GET /v2/domain/list` → `[]`, `GET /v4/domains` → `[]`).
- **Root cause of prior bounce**: live send was accepted (got TransactionIDs) but bounced at Gmail with `5.7.26 Unauthenticated email ... DMARC policy` (category SPFProblem) — because `From: noreply@auxi.app` had no ElasticEmail SPF/DKIM authenticating it. You cannot send `From: @gmail.com` (or any unauthenticated domain) via an ESP.
- **auxi.app DNS host**: nameservers `ns1.fr89.uk` / `ns2.fr89.uk` (fr89.uk = UK domain under Nominet UK). **NOT Cloudflare.** No wrangler/CF-API access → cannot programmatically write records.
- **Existing auxi.app DNS (untouched, do not disturb):**
  - apex A: `185.120.141.20`
  - apex SPF (TXT @): `v=spf1 a mx ip4:185.120.141.20 ~all` (no ElasticEmail include)
  - apex MX: `10 mail.auxi.app` (self-hosted inbound mail)
  - `_dmarc.auxi.app`: none
  - `api._domainkey.auxi.app`: none

## Action taken (account-level only — no DNS, no prod touched)

- Registered sending domain **`mail.auxi.app`** in ElasticEmail: `POST /v2/domain/add` (apikey, domain) → `{"success":true}`. Confirmed present in `/v2/domain/list` with all checks (spf/dkim/mx/dmarc) `false`, `verify: true`.
- **Why subdomain, not apex**: apex already runs self-hosted MX + SPF; isolating the ESP on a subdomain means the apex mail flow and reputation are never touched (per task recommendation).
- **Rollback**: `POST /v2/domain/delete?apikey=KEY&domain=mail.auxi.app`.

### Open recommendation
Consider re-registering on `send.auxi.app` / `em.auxi.app` instead of `mail.auxi.app`, because `mail.auxi.app` is ALSO the inbound mailserver hostname (the apex MX target). Co-locating ESP TXT auth records on the inbound mailserver host works (TXT vs A/MX don't conflict) but is less clean. One API call to switch + delete the current entry. Awaiting decision.

---

## DNS records to ADD (on the chosen subdomain — apex left untouched)

For `mail.auxi.app` (swap the subdomain if `send.auxi.app` is chosen):

| # | Type | Name / Host | Value |
|---|------|-------------|-------|
| 1 SPF | TXT | `mail.auxi.app` | `v=spf1 include:_spf.elasticemail.com ~all` |
| 2 DKIM | TXT | `api._domainkey.mail.auxi.app` | `k=rsa; t=s; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCbmGbQMzYeMvxwtNQoXN0waGYaciuKx8mtMh5czguT4EZlJXuCt6V+l56mmt3t68FEX5JJ0q4ijG71BGoFRkl87uJi7LrQt1ZZmZCvrEII0YO4mp8sDLXC8g1aUAoi8TJgxq2MJqCaMyj5kAm3Fdy2tzftPCV/lbdiJqmBnWKjtwIDAQAB` |
| 3 DMARC | TXT | `_dmarc.mail.auxi.app` | `v=DMARC1; p=none; rua=mailto:dmarc@auxi.app` |

Notes:
- SPF (#1) is a NEW record on the subdomain — there is no existing TXT on `mail.auxi.app`, so no merge and the apex SPF is never modified. (If apex were ever verified instead, MERGE `include:_spf.elasticemail.com` into the existing apex SPF — never create a second SPF record.)
- DKIM value (#2) is ElasticEmail's account-agnostic shared DKIM public key — verified live by resolving `api._domainkey.elasticemail.com` (TXT). Enter as a single string; drop surrounding quotes if the DNS UI adds them.
- DMARC (#3) starts at `p=none` (monitor). Change/remove `rua=` mailbox as desired; minimal valid form is `v=DMARC1; p=none`.
- Optional ElasticEmail open/click **tracking CNAME** is NOT required for transactional deliverability — skipped.
- Existing apex A / SPF / MX (`mail.auxi.app`) untouched.

---

## EMAIL_FROM change required

The adapter `services/email_elasticemail.py:106` reads `EMAIL_FROM` directly and builds `From = "Auxi <EMAIL_FROM>"` (`:128`). Verifying the subdomain means From must align with it.

- `wardrobe-backend/.env:84` currently `EMAIL_FROM=noreply@auxi.app` → change to `EMAIL_FROM=noreply@mail.auxi.app` (or `noreply@send.auxi.app`).
- **NOT yet applied** — awaiting subdomain confirmation. No code change needed.
- **Railway prod** needs the SAME var set (separate Railway `set_variables` action, on ship).

---

## Remaining steps (I execute once DNS is live)

1. Add the 3 DNS records at fr89.uk — **human/DNS-owner action, I cannot do it.**
2. Trigger ElasticEmail verification + poll `/v2/domain/list` until `spf` AND `dkim` go `true`.
3. Apply `EMAIL_FROM` change in `.env` (confirm-gated).
4. Re-test: `<full-venv-python> scripts/send_test_email.py duc2820@gmail.com` from `wardrobe-backend/`.
5. Confirm TransactionID shows **Delivered** (not SPFProblem) via `/v2/email/getstatus?...&showFailed=true`. User also checks duc2820@gmail.com inbox.

## Final delivery status
NOT yet delivering — pending DNS records (external) + domain verification. Last known send: bounced (SPFProblem). No new send attempted post-registration (would still bounce until DNS+verify).

## Unresolved questions
1. Subdomain: keep `mail.auxi.app` or switch to `send.auxi.app`/`em.auxi.app` (cleaner vs inbound mailserver host)? Recommend `send.auxi.app`.
2. Who controls fr89.uk DNS and can add the 3 records?
3. DMARC `rua` reporting mailbox — `dmarc@auxi.app` or other (or omit)?
4. When to set `EMAIL_FROM` on Railway prod (ship timing — tech-lead call).
