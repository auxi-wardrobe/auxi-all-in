# Macgie Privacy Policy — DRAFT (for CEO review)

> **Status:** DRAFT — not yet legally reviewed, not yet in app. Written to satisfy App Store blocker **B1** (explicit disclosure of AI third-party data sharing) and **B5** (reachable Privacy Policy). Mirrors the tone/structure of the existing Terms of Service (Figma node 3177:6809). Content reflects what the Auxi/Macgie app **actually** collects + sends, per the 2026-06-19 code audit.
>
> **Before shipping:** (1) CEO/legal review of wording; (2) confirm contact email + company legal entity; (3) host a canonical copy at a public URL (required by App Store Connect's Privacy Policy URL field); (4) reconcile against the App Store Connect "App Privacy" nutrition label.
>
> **Placeholders to fill:** `[LEGAL ENTITY NAME]`, `[JURISDICTION]`, hosted URL. Effective date set on publish.

---

## Macgie Privacy Policy

**Effective Date:** _[set on publish]_

This Privacy Policy explains how Macgie ("Macgie", "we", "us") collects, uses, shares, and protects your information when you use the Macgie mobile application and related services (the "Service"). By using Macgie, you agree to the practices described here. If you do not agree, please do not use the Service.

This Privacy Policy works together with our **Terms of Service**.

### 1. Information We Collect

We collect only what we need to run the Service:

**Account information**
- Email address and basic profile details, obtained when you sign in with **Apple** or **Google**.

**Photos and images you provide**
- Photos of your clothing and wardrobe items.
- Photos of yourself — including selfies and full-body photos — that you upload to use the virtual try-on and styling features.

**Style and wardrobe data**
- Body-shape and fit preferences you select, wardrobe item categories, tags, notes, outfit history, and your interactions with recommendations.

**Approximate location**
- Coarse location, used to fetch local weather so recommendations suit the conditions. We do **not** track precise or background location for advertising.

**Usage and analytics**
- Product-interaction events (screens viewed, features used) collected via **Mixpanel**, only after you opt in to analytics. Analytics data is stored with **EU data residency**. We configure analytics to avoid IP-based geolocation and to use internal identifiers only — not your email, phone, or social handle.

**Device and diagnostic data**
- Crash and error diagnostics via **Sentry**, configured to exclude personally identifying information.

### 2. How We Use Your Information

We use your information to:
- create and secure your account;
- generate **AI styling recommendations** and **virtual try-on images**;
- personalize suggestions based on your wardrobe, preferences, weather, and usage;
- maintain, debug, and improve the Service;
- communicate important service or policy updates.

### 3. AI Processing and Third-Party AI Providers — *important*

To generate outfit recommendations and virtual try-on images, Macgie sends relevant data — **including your wardrobe photos and the body/selfie photos you upload** — to third-party artificial-intelligence providers that process them on our behalf:

- **Google (Gemini)** — generates virtual try-on images and styling analysis.
- **OpenAI** — generates outfit reasoning and recommendations.

These providers process your photos and related data **solely to return a result to you**. Their handling of data is also governed by their own terms and privacy policies. We ask for your **explicit consent before your photos are sent to these AI providers**, and you can decline. If you decline, AI try-on and AI-generated recommendation features will be unavailable, but the rest of the app remains usable.

AI-generated content is provided for inspiration and may be inaccurate; see the Terms of Service.

### 4. How We Share Information

We share information only as described here:
- **AI providers** — as described in Section 3 (Google Gemini, OpenAI).
- **Login providers** — Apple and Google, to authenticate you.
- **Analytics** — Mixpanel (EU residency), only with analytics consent.
- **Diagnostics** — Sentry, for crash reporting (no PII).
- **Infrastructure** — our hosting provider (Railway) stores app data to operate the Service.

We do **not** sell your personal data, and we do **not** share your wardrobe or body data with advertisers. We may disclose information if required by law or to protect the rights and safety of users and the Service.

### 5. Data Retention

We keep your information for as long as your account is active or as needed to provide the Service. When you delete content or your account, we remove the associated data, subject to reasonable technical limitations and standard backup-retention periods. Aggregated or de-identified data that can no longer identify you may be retained.

### 6. Your Rights and Choices

- **Access / correction** — view and edit your profile and wardrobe in-app.
- **Deletion** — delete individual items or your entire account; account deletion removes your associated personal data subject to Section 5.
- **Withdraw AI consent** — stop using AI features at any time; you can revoke the AI-data-sharing consent.
- **Analytics opt-out** — analytics is opt-in; you can opt out in settings, and Mixpanel stays inert until you consent.

To exercise any right, contact us (Section 11).

### 7. Data Security

We protect your data with encryption in transit (HTTPS/TLS), secure credential storage on-device (iOS Keychain), and access controls on our backend. No method of transmission or storage is completely secure, but we work to protect your information using industry-standard measures.

### 8. International Data Transfers

Your data may be processed in countries other than where you live. Analytics data is stored with **EU data residency**; our **AI providers (Google, OpenAI) may process data in the United States or other regions**. Where required, we rely on appropriate safeguards for such transfers.

### 9. Children's Privacy

Macgie is not directed to children under **13**. We do not knowingly collect personal data from children under 13. If you are under the age required by your local laws to consent to digital services, use Macgie only with parental or guardian permission. If you believe a child has provided us data, contact us and we will delete it.

### 10. Changes to This Policy

We may update this Privacy Policy from time to time. For material changes, we will notify you in the app or by other reasonable means. Continued use after an update means you accept the revised Policy.

### 11. Contact

Questions about this Privacy Policy or your data:
**marketing@macgie.com** _(confirm whether a dedicated privacy@macgie.com should be used)_

Macgie is operated by `[LEGAL ENTITY NAME]`, `[JURISDICTION]`.

---

## Reviewer checklist (delete before publishing)

- [ ] CEO/legal approves wording, entity name, jurisdiction, contact email
- [ ] Confirm the **only** AI providers are Google Gemini + OpenAI (audit found both; verify no others added since)
- [ ] Confirm Mixpanel EU residency + Sentry PII-off statements still accurate
- [ ] Confirm retention/deletion claims match actual backend behavior (account-delete endpoint exists + purges photos)
- [ ] Host canonical copy at a public URL → paste into App Store Connect → App Privacy → Privacy Policy URL
- [ ] Reconcile this against the App Store Connect nutrition label (Photos/User Content, Email, Coarse Location, Product Interaction, Diagnostics, + third-party AI sharing)
- [ ] Set Effective Date on publish
