# AU-242 — UAC Authentication & Account Access Flow

**Linear**: https://linear.app/duncan-1/issue/AU-242
**Figma**: https://www.figma.com/design/0nXXMAR4Arf1ZfjtQvtBh0/Auxi?node-id=2849-8205&m=dev
**Status**: In Progress · Priority High · Assignee duc2820 · Project Auxi MVP 1.0
**Designer**: Viet Tran (vietdesign81@gmail.com)
**Design system**: Material 3 (custom Auxi tokens)
**Frame size**: 414×896 (iPhone Plus reference)
**Extracted**: 2026-05-21

---

## Screen index

| # | Node | File | Purpose |
|---|---|---|---|
| 1 | `2849:10085` | [01-welcome.md](01-welcome.md) | Landing — 3 sign-in options + language link |
| 2 | `2849:10108` | [02-language-settings.md](02-language-settings.md) | List-based language switcher |
| 3 | `2849:10143` | [03-email-input.md](03-email-input.md) | Email entry — signup or signin pre-check |
| 4 | `2849:10296` | [04-password-creation-typing.md](04-password-creation-typing.md) | Password create — typing, criteria pending |
| 5 | `2849:10379` | [05-password-creation-valid.md](05-password-creation-valid.md) | Password create — all criteria met, CTA enabled |
| 6 | `2849:10276` | [06-verify-email.md](06-verify-email.md) | Open mail app + resend cooldown |
| 7 | `2849:10267` | [07-email-google-notice.md](07-email-google-notice.md) | Email already linked to Google → ép OAuth |
| 8 | `2849:10205` | [08-email-input-error.md](08-email-input-error.md) | Email error state — invalid format |
| 9 | `2849:10462` | [09-signin.md](09-signin.md) | Returning user — email readonly + password |
| 10 | `2849:10535` | [10-forgot-request.md](10-forgot-request.md) | Forgot password — submit email |
| 11 | `2849:10552` | [11-forgot-check-mail.md](11-forgot-check-mail.md) | Reset email sent confirmation |
| 12 | `2849:10570` | [12-reset-new-password.md](12-reset-new-password.md) | Set new password from reset link |
| 13 | `2849:10099` | [13-verified-success.md](13-verified-success.md) | Terminal "Verified!" — convergence point |

---

## Flow (mapped với 28 AC scenarios trong AU-242)

```
Welcome (1) ──┬─[Continue with Email]──► Email input (3)
              │                              ├─[valid + new]──► Pass create (4→5) ──► Verify email (6) ──► Verified! (13)
              │                              ├─[Google-linked]─► Notice (7) ──► OAuth
              │                              └─[invalid format]──► Email error (8) — inline
              │
              ├─[Continue with Google]──► Google OAuth
              ├─[Continue with Apple]──► Apple OAuth (no dedicated screen — system flow)
              │
              ├─[Sign in path — returning verified user]──► Sign in (9) ──► Home
              │                                              └─[Forgot]──► Forgot req (10) ──► Check mail (11) ──► Reset (12) ──► Verified! (13)
              │
              └─[Language link top-right]──► Language settings (2) ──► back
```

---

## Consolidated design tokens

### Colors (Auxi neutral palette + accents)
| Token | Hex | Usage |
|---|---|---|
| `--background/neutral/subtlest` | `#ffffff` | Most screen backgrounds |
| `--background/primary/neutral_50` | `#fcfcfd` | Welcome/Verified terminal screens |
| `--background/neutral/base` | `#1d1f23` | Primary CTA bg, Apple button |
| `--border/neutral/base` | `#1d1f23` | Secondary button outline |
| `--border/neutral/bold_200` | `#7a7f89` | Text field default border |
| `--color/neutral/100-#f2f4f7` | `#f2f4f7` | Read-only / filled disabled field |
| `--text/neutral/base` | `#1d1f23` | Primary text |
| `--text/neutral/subtle_100` | `#40444d` | Read-only value, satisfied criteria |
| `--text/neutral/subtle_200` | `#7a7f89` | Placeholder, pending criteria |
| `--text/primary/base` | `#f2efec` | Primary CTA label (on dark bg) |
| `--text/danger/base` | `#bb251a` | Error text |
| `--text/info/base` | `#1465b4` | "Forgot your password?" link |
| `M3/sys/light/on-surface-variant` | `#49454f` | Material 3 list item supporting text |

### Typography (Poppins + Inter + Roboto stack)
| Style | Spec | Family |
|---|---|---|
| `H1/Bold` | 40 / 52 | Poppins 700 |
| `H4/Bold` | 24 / 32 | Poppins 700 |
| `Text-md (l-24)/Semibold` | 16 / 24 | Inter 600 |
| `Text-md (l-24)/Medium` | 16 / 24 | Poppins 500 |
| `Text-md (l-24)/Regular` | 16 / 24 | Poppins 400 (Noto Sans for vi) |
| `Text-xs/Regular` | 12 / 16 | Inter 400 |
| `Text-xs/Medium` | 12 / 16 | Inter 500 |
| `static/body-large` | 16 / 24 | Poppins 400 (Material 3 body) |
| `body/small` | 12 / 16 + 0.4px tracking | Roboto 400 |

### Spacing tokens
- `--body` = **24px** (screen horizontal padding)
- `--dimension/24` = 24px · `--dimension/16` = 16px · `--dimension/8` = 8px · `--dimension/4` = 4px
- Button paddingX **20** / paddingY **16** · Button height **56**
- List item min-h **56px**, gap 16px
- Header height **107px** (back 45×45 left, trailing slot 47×47 right)
- Status bar / safe area top **112px**, bottom **12px**

### Radii
- Screen card 18px · panel 16px
- CTA button 16px · text button 12px
- Text field 8px · radio 100px (pill)

---

## Reused components

| Component | Figma node | Notes |
|---|---|---|
| `Button — Primary/Size56` | `470:2206` (no icon), `470:2264` (with icon) | Main CTA, dark bg + light label |
| `Button — Secondary/Size56` | `470:2282` | Outlined, dark border, white bg |
| `Button — Text/Size44` | — | "English" link, "Logout" |
| `Text field` | `1752:24683` | M3 outlined + filled (read-only) variants |
| `Header` (top app bar) | `425:2322` | Back chevron left, empty 47×47 slot right (feedback?) |
| `Type=Round/Size=Small` icon button | `348:16292` | Circle submit chevron (rotated 180° for forward arrow) |
| `Radio buttons` (M3) | `329:1207` | Language list |
| `Divider — Middle-inset` (M3) | `483:1550` | Inside language list |
| `HomeIndicator` | `345:15612` | iOS bottom indicator (keyboard mocks) |
| `imgGroup42` brand mark | — | Logo (currently "Mg" — wireframe) |

**Ignore**: `AlphabeticKeyboard` + 31 `_Key` instances — real iOS keyboard renders natively in RN.

---

## Open questions — gộp 3 batch, gửi PM / anh Việt

### Branding & copy
1. **Brand name** Figma render "Macgie"/"Maogie" — ticket dùng "Auxi". Welcome headline + Verify body cần thống nhất.
2. **Password screen title** "What is your email" copy-paste artifact ở màn 04/05 — chắc phải là "Create a password".
3. **Typo Figma**:
   - 08: "Please enter a valid email **adress**" (thiếu d)
   - 13: "You have successfully verified account" (thiếu "your")
   - 10: "We'll send a password **reseting** to your email" (sai chính tả + thiếu "link")
   - 11: double space "We've sent  a password reset link to:"
4. **Welcome legal links**: "Terms of Service" / "Privacy Policy" không styled riêng → confirm tappable substrings + color treatment.
5. **vi translations**: cần dịch toàn bộ copy cho locale vi (đặc biệt screen 07, 08, 13).
6. **Empty `feedback` slot top-right header (47×47)** trên các màn input — feature thật hay placeholder?

### Behavior / state
7. **Password criteria icon** — Figma dùng cùng SVG cho pending vs satisfied (chỉ đổi text color). Confirm có swap sang check mark khi pass không.
8. **Submit chevron** (icon-only) trên màn signin (9) và reset-new-password (12) — đây có phải submit cuối cùng hay thiếu một CTA "Sign in" / "Reset password" label?
9. **Resend cooldown format** `(00s)` — final format `(NN s)` hay chỉ `(NNs)`? Sau timer = 0 đổi label về `Resend verification email` không?
10. **Error state border màn 08** — vẫn `#7a7f89` (neutral grey) thay vì danger red. M3 chuẩn là đổi border đỏ. Intentional?
11. **Sign in error state** màn 9 không có design — mobile-dev tự suy `--text/danger/base` + helper text.
12. **Eye icon visibility toggle** màn 9/12 — confirm icon swap (eye / eye-off) hay chỉ 1 trạng thái.

### Routing / convergence
13. **Verified! (13) routes**:
    - Từ signup → Home? Onboarding (AU-243)?
    - Từ password reset → Home if session restored? Login pre-filled?
14. **"Back to Login" màn 11** — pop về Welcome (1) hay Sign in (9)?
15. **Linear AC vs Figma 11**: AC nhắc "Back to login" + "Open mail app". Figma chỉ có "Back to Login". Drop hay add?

### Spec gaps
16. **Email screen #6 vs #8** — đều layer name "input email" nhưng content khác. Designer nên rename node cho rõ.
17. **Password rules nhất quán signup (4/5) vs reset (12)?** Cả hai đều `8 chars + lowercase + number`. Confirm không bị regression khi anh Việt bổ sung uppercase/special-char sau.
18. **Confirm-password field** không có trên Figma — confirm product không yêu cầu double-entry.
19. **Welcome screen language toggle "English"** — text button hay link? Khi nhấn navigate hay open bottom sheet?
20. **Welcome screen có 3 hay 4 buttons?** Agent batch 1 nói "4 buttons", layout thực tế từ ticket có 3 (Google/Apple/Email). Recount.

---

## Wireframe caveat

Design có dấu hiệu **wireframe state**, không phải hi-fi:
- Logo `Mg` (Macgie) chưa rename Auxi
- Color mono đen/trắng/xám, chưa có accent màu (chỉ #1465b4 cho link)
- Typography mix Poppins/Inter/Roboto — có thể chưa thống nhất font ship

→ **Confirm với anh Việt trước khi implement faithfully**, hoặc treat đây là layout-final + cho phép mobile-dev áp dụng theme Auxi hiện tại (`auxi/src/theme/`).
