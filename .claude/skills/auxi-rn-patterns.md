---
name: auxi-rn-patterns
description: React Native + TanStack Query patterns specific to the Auxi mobile app. Use when adding screens, services, or queries inside auxi/. Covers navigation registration, apiClient wrapping, theme tokens, SVG imports, and i18n placement.
---

# Auxi RN Patterns

These are the patterns Auxi uses in production. Follow them — deviating
breaks the project's known-working assumptions and creates silent runtime
bugs (especially around navigation registration).

## Adding a new screen

**Two-place rule** — both required, or you get cold-start crashes:

1. **Type registration**: `auxi/src/types/navigation.ts`

```ts
export type AppStackParamList = {
  // ...
  MyNewScreen: { itemId: string };  // ← add the route + its params
};
```

2. **Component registration**: `auxi/src/navigation/AppNavigator.tsx`

```tsx
import { MyNewScreen } from '../screens/MyNewScreen';
// ...
<Stack.Screen name="MyNewScreen" component={MyNewScreen} />
```

If you skip either, the navigation type is wrong (1) or `navigate` throws
at runtime (2). There is no compile-time guard.

## Primitives-first rule

**Screens compose primitives — they do NOT build from scratch.**

Auxi has `auxi/src/components/primitives/FigmaPrimitives.tsx` for the
shared building blocks (TopIconButton, DividerRow, BottomSheetSurface,
PillButton, etc.). Every new screen must:

1. **Audit existing primitives first.** Grep `auxi/src/components/primitives/`
   and `auxi/src/components/atoms/` for components that match the Figma node.
2. **If a primitive exists** → reuse it. Do NOT re-implement.
3. **If Figma shows a component pattern reused across screens but no RN
   primitive exists** → create the primitive FIRST in `primitives/`, then
   compose. Do NOT inline a one-off `<View>` stack on the screen with the
   intent to "extract later."
4. **Token-only styling.** Every `style={{}}` value comes from `theme.ts`
   (colors, spacing, fonts, radius). No hex literal in screens. No literal
   font family string in screens — go through `theme.text.*` preset.

Quick scan before screening (`auxi/`):
```bash
ls auxi/src/components/primitives/
ls auxi/src/components/atoms/
grep -rn "export const" auxi/src/components/primitives/ auxi/src/components/atoms/
```

Why: every per-screen inline component is a source of drift (same row layout
implemented 3 ways across 3 screens). Primitives stabilize the visual
language and reduce qa-ui finding count.

Anti-pattern (don't ship):
```tsx
// In MyScreen.tsx — inlining a row, hex literal, hardcoded font
<View style={{ flexDirection: 'row', padding: 16, backgroundColor: '#FAFAFA' }}>
  <Text style={{ fontFamily: 'Inter-Medium', fontSize: 14 }}>{label}</Text>
</View>
```

Correct:
```tsx
import { DividerRow } from '../components/primitives/FigmaPrimitives';
// DividerRow already encodes the Figma row pattern with theme tokens
<DividerRow label={label} value={value} />
```

## Service file pattern (HTTP)

Never import axios in screens or hooks. New API surfaces become a service.

```ts
// auxi/src/services/myFeature.ts
import { apiClient } from './apiClient';

export type MyFeatureItem = { id: string; name: string };

export const myFeatureApi = {
  list: () => apiClient.get<MyFeatureItem[]>('/my-feature'),
  get:  (id: string) => apiClient.get<MyFeatureItem>(`/my-feature/${id}`),
  create: (data: Omit<MyFeatureItem, 'id'>) =>
    apiClient.post<MyFeatureItem>('/my-feature', data),
};
```

Screens consume this via TanStack Query hooks, not directly.

## TanStack Query hook pattern

```ts
// auxi/src/hooks/useMyFeatureList.ts
import { useQuery } from '@tanstack/react-query';
import { myFeatureApi } from '../services/myFeature';

export const useMyFeatureList = () =>
  useQuery({
    queryKey: ['my-feature', 'list'],
    queryFn: () => myFeatureApi.list().then(r => r.data),
  });
```

Mutation invalidation:

```ts
const qc = useQueryClient();
useMutation({
  mutationFn: myFeatureApi.create,
  onSuccess: () => qc.invalidateQueries({ queryKey: ['my-feature'] }),
});
```

Query key convention: `[resource, scope, ...filters]`. Keep them stable.

## Theme tokens — no literal hex

```tsx
// WRONG — adds drift
<View style={{ backgroundColor: '#FF6B6B' }} />

// RIGHT
import { theme } from '../theme/theme';
<View style={{ backgroundColor: theme.colors.accent }} />
```

If a token doesn't exist, add it to `src/theme/theme.ts` with a
descriptive name first, then use it.

## SVG icons

```tsx
import IconHeart from '../assets/icons/icon_heart.svg';

<IconHeart width={20} height={20} fill={theme.colors.accent} />
```

`react-native-svg-transformer` rewrites the import to a React component.
Don't use `<Image source={...}>` for SVGs — colors won't theme correctly.

## Onboarding copy & artwork

```ts
// auxi/src/onboarding/config.ts
export const onboardingScreens = {
  welcome: {
    title: 'Welcome to Auxi',
    subtitle: '...',
    illustration: require('../assets/onboarding/welcome.png'),
  },
  // ...
};
```

Screens read from this config, not inline strings. Easy lift to
`i18next` later — translation keys map cleanly.

## i18n

Strings live in `auxi/src/translations/{en,vi}/...json`. Use the
`useTranslation` hook:

```tsx
const { t } = useTranslation();
<Text>{t('home.greeting', { name: user.firstName })}</Text>
```

Don't ship hardcoded user-visible strings.

## Auth + Keychain

JWT lives in `react-native-keychain`. Read/write through `AuthContext`.

```tsx
const { user, login, logout, completeOnboarding } = useAuth();
```

Never reach into keychain APIs directly from screens.

## Verification before declaring done

```bash
cd auxi
npx tsc --noEmit                # legacy _HomeScreen errors are expected
yarn lint                       # baseline: 4 errors + 3 warnings
yarn test                       # if you added/modified anything testable
yarn ios:sim                    # smoke if UI changed
```

## Common pitfalls

| Symptom | Likely cause |
|---|---|
| App crashes on cold start | New screen not in `AppNavigator.tsx` |
| `Property 'X' does not exist on AppStackParamList` | New route missing from `navigation.ts` |
| SVG renders as broken image | Used `<Image>` instead of importing as component |
| Token not persisting | Bypassed `AuthContext`, wrote directly to AsyncStorage |
| Recommendation re-fetches infinitely | Query key includes a non-stable reference |
| New literal hex value flagged in review | Skipped `theme.ts` |
