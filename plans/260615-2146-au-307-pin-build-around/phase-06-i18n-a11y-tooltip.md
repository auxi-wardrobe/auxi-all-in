# Phase 06 — i18n + a11y + Tooltip

## Context links

- Spec: [`spec.md`](./spec.md) §4.1 (12 i18n keys), §7 (tooltip UX, modal CTAs), §8 (tooltip persistence default), §9 (tooltip pointer-events risk)
- Locale files: `auxi/src/i18n/locales/en.json`, `vi-VN.json`, `fr-FR.json`
- Existing tooltip patterns in repo (reuse animation/style if any) — grep `Tooltip` in `auxi/src/components`

## Overview

- **Priority:** P3 (polish; gates phase 07 Maestro because flows select by a11y labels)
- **Status:** pending
- **Brief:** Add 12 i18n keys per spec §4.1 across en, vi-VN, fr-FR. Create `PinnedItemTooltip` (shows for first 3 pin actions per session, then auto-dismisses). Add a11y labels on pin badge, modal CTAs, tooltip.

## Key insights

- Three-locale parity is enforced — every key MUST exist in all three locale files (validated via grep diff).
- Tooltip session counter lives in memory (session-only); no AsyncStorage persistence.
- `pointerEvents="box-none"` on tooltip container — taps pass through to underlying tile (spec §9 risk).
- a11y labels read from i18n — Maestro selectors in phase 07 depend on these.
- vi-VN + fr-FR translations: keep tone matching existing copy (CEO-approved tone — short, direct).

## Requirements

**Functional:**
- 12 i18n keys present in all 3 locale files with matching shape.
- `PinnedItemTooltip` renders adjacent to pinned tile for first 3 pin actions per session.
- Tooltip auto-dismisses after 3-second display or on next user interaction (whichever first).
- After 3 pin actions, tooltip never shows again that session.
- a11y labels:
  - Pin badge: `pin.a11y_pinned_badge` ("Pinned item, double-tap to unpin")
  - Modal primary CTA: i18n `pin.build_cta`
  - Modal secondary CTA: i18n `pin.cancel_cta`
  - Tooltip: `pin.tooltip_unpin` ("Touch to unpin")
- Modal overlay `accessibilityViewIsModal={true}` (iOS) + focus trapped.

**Non-functional:**
- Tooltip pointer-events do NOT block tile interactions.
- Locale JSON files maintain alphabetical key order (existing convention; verify).
- No hard-coded strings introduced anywhere in pin code paths.

## Architecture

```
Session-scoped tooltip counter
  └── const tooltipCountRef = useRef(0)  // HomeScreen
  └── on CONFIRM_PIN dispatch → tooltipCountRef.current++ if < 3
  └── tooltip visible when current pin action <= 3 && timer not expired

PinnedItemTooltip
  ├── pointerEvents="box-none" container
  ├── absolute-positioned bubble near pinned tile
  ├── auto-dismiss timer (3s)
  └── dismiss on next dispatch (any pin event)

a11y wiring
  ├── Pin badge: accessibilityLabel={t('pin.a11y_pinned_badge')}, accessibilityRole="button"
  ├── Modal CTAs: accessibilityLabel from i18n
  └── Modal container: accessibilityViewIsModal={true}
```

## Related code files

**Create:**
- `auxi/src/components/features/PinnedItemTooltip.tsx`

**Modify:**
- `auxi/src/i18n/locales/en.json` — add 12 keys (+ 1 a11y key = 13 total; see below)
- `auxi/src/i18n/locales/vi-VN.json` — same 13 keys, vi translation
- `auxi/src/i18n/locales/fr-FR.json` — same 13 keys, fr translation
- `auxi/src/screens/HomeScreen.tsx` — add `tooltipCountRef`, render `<PinnedItemTooltip />` when conditions met; pass a11y label to pin badge
- `auxi/src/components/features/PinConfirmModal.tsx` (from phase 03) — wire a11y labels on CTAs, `accessibilityViewIsModal`

## i18n keys (canonical EN copy)

Per spec §4.1 + §7 + §8 + a11y additions:

| Key | EN |
|---|---|
| `pin.modal_title` | Keep this item |
| `pin.modal_subtitle` | We'll keep this piece and remix the rest. |
| `pin.build_cta` | Build around this |
| `pin.cancel_cta` | Cancel |
| `pin.replace_title` | Replace pinned item? |
| `pin.unpinned_toast` | Item unpinned |
| `pin.fallback_message` | We couldn't fully match this item, but here's the closest fit. |
| `pin.error_message` | We couldn't build an outfit. Try again. |
| `pin.network_error` | No connection. Check your network and retry. |
| `pin.item_unavailable` | This item is no longer available. |
| `pin.tooltip_unpin` | Touch to unpin |
| `pin.guest_blocker` | Sign in to build outfits. |
| `pin.a11y_pinned_badge` | Pinned item, double-tap to unpin |
| `pin.generating_status` | Generating |
| `pin.skeleton_loading` | Loading outfit slot |

(Also needed by phase 04: `pin.generating_status`, `pin.skeleton_loading` — included here for one-shot locale parity check.)

## Implementation steps

1. **Add keys to en.json** alphabetically under `pin.*` namespace (or top-level if convention is flat — match existing pattern).
2. **Add same keys to vi-VN.json** — translations:
   - `pin.modal_title` → "Giữ món đồ này"
   - `pin.modal_subtitle` → "Mình sẽ giữ món này và phối lại phần còn lại."
   - `pin.build_cta` → "Phối quanh món này"
   - `pin.cancel_cta` → "Hủy"
   - `pin.replace_title` → "Thay món đã ghim?"
   - `pin.unpinned_toast` → "Đã bỏ ghim"
   - `pin.fallback_message` → "Chưa khớp hoàn hảo, đây là phương án gần nhất."
   - `pin.error_message` → "Không phối được outfit. Thử lại."
   - `pin.network_error` → "Mất kết nối. Kiểm tra mạng và thử lại."
   - `pin.item_unavailable` → "Món này không còn nữa."
   - `pin.tooltip_unpin` → "Chạm để bỏ ghim"
   - `pin.guest_blocker` → "Đăng nhập để phối outfit."
   - `pin.a11y_pinned_badge` → "Đã ghim, chạm đúp để bỏ ghim"
   - `pin.generating_status` → "Đang phối"
   - `pin.skeleton_loading` → "Đang tải"
3. **Add same keys to fr-FR.json** — translations:
   - `pin.modal_title` → "Garder cet article"
   - `pin.modal_subtitle` → "On garde celui-ci et on remixe le reste."
   - `pin.build_cta` → "Composer autour"
   - `pin.cancel_cta` → "Annuler"
   - `pin.replace_title` → "Remplacer l'article épinglé ?"
   - `pin.unpinned_toast` → "Article désépinglé"
   - `pin.fallback_message` → "Match imparfait, voici la meilleure option."
   - `pin.error_message` → "Impossible de composer la tenue. Réessayez."
   - `pin.network_error` → "Pas de connexion. Vérifiez votre réseau."
   - `pin.item_unavailable` → "Cet article n'est plus disponible."
   - `pin.tooltip_unpin` → "Touchez pour désépingler"
   - `pin.guest_blocker` → "Connectez-vous pour composer."
   - `pin.a11y_pinned_badge` → "Article épinglé, double-tap pour désépingler"
   - `pin.generating_status` → "Composition"
   - `pin.skeleton_loading` → "Chargement"
4. **Parity check** — `diff <(jq 'keys' en.json) <(jq 'keys' vi-VN.json)` returns empty; same for fr-FR.
5. **`PinnedItemTooltip.tsx`**:
   ```tsx
   type Props = {
     visible: boolean;
     anchorPosition: { x: number; y: number };
     onDismiss: () => void;
   };
   ```
   - Absolute-positioned bubble.
   - `pointerEvents="box-none"` on container.
   - `useEffect` auto-dismiss timer 3000ms.
   - a11y: `accessibilityLabel={t('pin.tooltip_unpin')}`, `accessibilityRole="tooltip"` (or `"text"` if iOS doesn't support `tooltip`).
6. **HomeScreen tooltip wiring**:
   ```ts
   const tooltipCountRef = useRef(0);
   const [tooltipVisible, setTooltipVisible] = useState(false);
   useEffect(() => {
     if (pinState.pinnedItemId && tooltipCountRef.current < 3) {
       setTooltipVisible(true);
       tooltipCountRef.current++;
     }
   }, [pinState.pinnedItemId]);
   ```
   Render `<PinnedItemTooltip visible={tooltipVisible} anchorPosition={pinnedTileLayout} onDismiss={() => setTooltipVisible(false)} />`.
7. **a11y on pin badge** (in OutfitTile or HomeScreen badge render):
   - `accessibilityLabel={t('pin.a11y_pinned_badge')}`
   - `accessibilityRole="button"`
   - `accessibilityState={{ selected: isPinned }}`
8. **a11y on modal CTAs** (`PinConfirmModal.tsx`):
   - Primary: `accessibilityLabel={t('pin.build_cta')}`, `accessibilityRole="button"`
   - Secondary: `accessibilityLabel={t('pin.cancel_cta')}`, `accessibilityRole="button"`
   - Modal container: `accessibilityViewIsModal={true}`
9. **Run gates:** `npx tsc --noEmit && yarn lint`; manually verify VoiceOver reads labels on iOS sim.

## Todo

- [ ] Add 15 keys to en.json
- [ ] Add 15 keys to vi-VN.json with translations
- [ ] Add 15 keys to fr-FR.json with translations
- [ ] Locale parity diff = empty
- [ ] Create `PinnedItemTooltip.tsx` with pointer-events safe container
- [ ] Wire `tooltipCountRef` session counter in HomeScreen
- [ ] Wire a11y labels on pin badge
- [ ] Wire a11y labels on modal CTAs + modal container
- [ ] tsc + lint clean

## Success criteria

- All 3 locale JSONs have identical `pin.*` keyset.
- Pinning an item shows tooltip first 3 times in session; never again 4th.
- Tooltip auto-dismisses after 3s.
- Tile underneath tooltip remains tappable (manual check).
- VoiceOver on iOS reads "Pinned item, double-tap to unpin" on badge.
- VoiceOver reads "Build around this" / "Cancel" on modal CTAs.

## Risk assessment

| Risk (from spec §9) | Mitigation |
|---|---|
| Tooltip blocks interactions | `pointerEvents="box-none"` on container |
| Tooltip persists / over-shows | Session counter ref capped at 3; auto-dismiss timer |
| Locale drift (key missing in one file) | `jq keys` parity diff in PR review |
| a11y label mismatch with i18n | Single source: `t('pin.a11y_*')` reads from locale files |
| Translation tone off | vi-VN + fr-FR translations follow existing repo style; CEO can adjust post-merge |

## Security considerations

- No new auth surface.
- No PII in translation strings.

## Next steps

- Ships in **PR-FE-core** with phases 03, 04, 05.
- Phase 07 Maestro selectors depend on these a11y labels — must merge i18n before Maestro flow.
- Translation review: ping CEO if vi-VN or fr-FR tone needs polish (non-blocking; ship with current copy).
