# Mobile Standards (React Native)

React Native 0.83 + React 19 + TypeScript 5.8 conventions for `auxi/`.

---

## Key Rules

### 1. testID on Every Interactive Element

**MANDATORY.** Maestro QA automation depends on testID selectors.

```typescript
// Format: <feature>-<element>-<state-or-index>
// Examples:
// home-outfit-card-0        (index 0)
// home-mode-pill-safe       (state/variant)
// auth-login-submit         (action button)
// wardrobe-filter-category  (filter option)

// CORRECT
<Pressable
  testID="home-outfit-card-0"
  onPress={() => handleCardTap(0)}
>
  <Text accessibilityLabel="View outfit details">View</Text>
</Pressable>

// WRONG - No testID
<Pressable onPress={() => {}}>
  <Text>View</Text>
</Pressable>
```

**testID vs accessibilityLabel:**
- **testID:** Machine selector (Maestro automation)
- **accessibilityLabel:** Human label (screen readers, VoiceOver)

```typescript
// Icon-only button: BOTH required, different values
<Pressable
  testID="home-heart-toggle-unsaved"
  accessibilityLabel="Save item"
  onPress={toggleFavorite}
>
  <HeartIcon />
</Pressable>

// Text button: testID required, accessibilityLabel optional
<Pressable
  testID="auth-login-submit"
  onPress={submitLogin}
>
  <Text>Sign In</Text>
</Pressable>
```

### 2. Navigation Registration Rule

**New screens MUST be registered in TWO places:**

1. **`src/types/navigation.ts`** — Add param type
2. **`src/navigation/AppNavigator.tsx`** — Add route

Skip either = silent runtime crash.

```typescript
// src/types/navigation.ts
export type AppStackParamList = {
  Home: undefined;
  Wardrobe: undefined;
  ItemDetail: { itemId: string };  // ← Your new screen
  NewScreen: { param: string };    // ← With params
};

// src/navigation/AppNavigator.tsx
<Stack.Navigator>
  <Stack.Screen name="Home" component={HomeScreen} />
  <Stack.Screen name="NewScreen" component={NewScreen} />
</Stack.Navigator>
```

### 3. Service-Layer-Only API Calls

Never import axios directly from screens. Always use services.

```typescript
// CORRECT
import { recommendationService } from '../services/recommendation-service';

const HomeScreen = () => {
  const { data: outfit } = useQuery({
    queryKey: ['outfit'],
    queryFn: () => recommendationService.getRecommendation({ occasion: 'casual' })
  });
};

// WRONG - Direct axios
import axios from 'axios';
const HomeScreen = () => {
  const handleClick = async () => {
    const response = await axios.get('/api/recommendation?occasion=casual');
  }
};
```

**Service structure:**
```typescript
// src/services/recommendation-service.ts
import { apiClient } from './api-client';

export const recommendationService = {
  getRecommendation: async (params: { occasion: string; weather?: string }) => {
    const response = await apiClient.get('/recommendation', { params });
    return response.data;
  },
  
  submitFeedback: async (outfitId: string, feedback: 'like' | 'dislike') => {
    return apiClient.post(`/recommendation/${outfitId}/feedback`, { feedback });
  }
};
```

### 4. SVG Icon Import

```typescript
// CORRECT - Import SVG as component
import HeartIcon from '../assets/icons/heart.svg';

const FavoriteButton = () => (
  <Pressable testID="favorite-toggle" onPress={toggle}>
    <HeartIcon width={24} height={24} fill={isFavorited ? 'red' : 'gray'} />
  </Pressable>
);

// WRONG - Don't use Image for SVG
import { Image } from 'react-native';
<Image source={require('../assets/icons/heart.svg')} />
```

### 5. Theme Tokens (No Hardcoded Colors)

```typescript
// src/theme/theme.ts
export const theme = {
  colors: {
    primary: '#007AFF',
    danger: '#FF3B30',
    neutral: {
      dark: '#000000',
      light: '#FFFFFF',
      gray300: '#D1D1D6'
    }
  },
  spacing: {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32
  }
};

// CORRECT - Use theme
import { theme } from '../theme/theme';

const styles = StyleSheet.create({
  button: {
    backgroundColor: theme.colors.primary,
    paddingHorizontal: theme.spacing.md
  }
});

// WRONG - Hardcoded hex
const styles = StyleSheet.create({
  button: {
    backgroundColor: '#007AFF',  // BAD
    paddingHorizontal: 16
  }
});
```

### 6. State Management (TanStack Query + AuthContext)

```typescript
// TanStack Query for server state (API data)
import { useQuery } from '@tanstack/react-query';

const HomeScreen = () => {
  const { data: outfit, isLoading, error } = useQuery({
    queryKey: ['outfit', occasion],
    queryFn: () => recommendationService.getRecommendation({ occasion })
  });
};

// AuthContext for user state (login/logout/onboarding)
import { useAuth } from '../context/AuthContext';

const SettingsScreen = () => {
  const { user, logout } = useAuth();
  return <Text>{user.email}</Text>;
};

// DON'T add Redux, Zustand, or MobX - TanStack Query + AuthContext is sufficient
```

### 7. TypeScript Strict Mode

- All files: `"strict": true` in tsconfig.json
- No `any` without explicit `// @ts-ignore` comment + reason
- All function params and returns typed

```typescript
// CORRECT
interface RecommendationParams {
  occasion: 'casual' | 'formal' | 'sporty';
  weather: string;
}

const getOutfit = async (params: RecommendationParams): Promise<Outfit> => {
  return recommendationService.getRecommendation(params);
};

// WRONG
const getOutfit = async (params: any) => {
  return recommendationService.getRecommendation(params);
};
```

### 8. Onboarding Config

Don't hardcode onboarding copy. Use `src/onboarding/config.ts`:

```typescript
// src/onboarding/config.ts
export const onboardingConfig = {
  welcome: {
    title: 'Welcome to Auxi',
    subtitle: 'Let's personalize your experience'
  },
  stylePreference: {
    title: 'What's your style?',
    options: [
      { id: 'casual', label: 'Casual' },
      { id: 'formal', label: 'Formal' }
    ]
  }
};

// In component
import { onboardingConfig } from '../onboarding/config';

const WelcomeScreen = () => (
  <Text>{onboardingConfig.welcome.title}</Text>
);
```

---

## Project Structure

```
auxi/src/
├── screens/              # Screen components
├── services/             # API clients (service layer only)
├── components/
│   ├── atoms/            # Single-purpose (Button, Badge, TextWrapper)
│   ├── layout/           # Layout containers
│   ├── features/         # Feature-specific (WardrobeGrid, RecommendationCard)
│   └── primitives/       # RN primitives + custom wrappers
├── context/              # React Context (AuthContext)
├── navigation/           # Navigation setup (AppNavigator, AuthNavigator)
├── theme/                # Design tokens (colors, spacing, typography)
├── translations/         # i18n locales (i18next)
├── types/                # TypeScript definitions (navigation params, API schemas)
├── config/               # App-level configuration
├── utils/                # Helpers (formatting, device info, validation)
└── onboarding/           # Onboarding copy + config
```

---

## Verification Before Shipping

```bash
npx tsc --noEmit              # TypeScript check (legacy errors expected)
yarn lint                      # ESLint (baseline: 4 errors in _HomeScreen, 3 warnings)
yarn test                      # Jest tests
yarn ios:sim                   # iOS simulator smoke test
maestro test maestro/flows/... # Individual QA flow
```

---

## Known Issues

- **Dual HomeScreen:** `HomeScreen.tsx` (current) and `_HomeScreen.tsx` (legacy, ~941 LOC) coexist. Legacy pending deletion.
- **API config hardcoded:** `localhost:5001` in `apiClient.ts`. Should be externalized via `.env` / react-native-config.
- **Onboarding dual flow:** Legacy `GenderPreference → StylePreference` coexists with new `PreferenceSeed → FitPreference → OutfitApproval → OnboardingConfirmation`. Product decision pending.

---

## Common Patterns

### Fetching Data with Loading/Error States

```typescript
const MyScreen = () => {
  const { data, isLoading, error } = useQuery({
    queryKey: ['mydata'],
    queryFn: () => myService.fetch()
  });

  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorCard message={error.message} />;
  
  return <DataDisplay data={data} />;
};
```

### Mutation with Optimistic Update

```typescript
const { mutate: updateItem } = useMutation({
  mutationFn: (item: Item) => wardrobeService.updateItem(item),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['items'] });
  },
  onError: (error) => {
    Alert.alert('Error', error.message);
  }
});

<Pressable testID="update-button" onPress={() => updateItem(item)}>
  <Text>Update</Text>
</Pressable>
```

### Custom Hook for Common Logic

```typescript
// hooks/use-recommendation.ts
export const useRecommendation = (occasion: string) => {
  return useQuery({
    queryKey: ['recommendation', occasion],
    queryFn: () => recommendationService.getRecommendation({ occasion })
  });
};

// In component
const { data: outfit } = useRecommendation('casual');
```
