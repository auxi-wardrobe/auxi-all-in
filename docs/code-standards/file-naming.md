# File Naming Conventions

Self-documenting filenames help developers and LLM tools (Grep, Glob, Search) understand purpose instantly without reading content.

---

## JavaScript/TypeScript/Python/Shell

**Format:** `kebab-case` for all filenames

**Principle:** Descriptive is always better than brief. A 40-character filename is clearer than a 6-character abbreviation.

### Examples by Type

| Type | Good | Bad | Why |
|------|------|-----|-----|
| React Component | `outfit-card.tsx` | `card.tsx`, `OCard.tsx` | Avoids naming collision with layout cards, utility cards, etc. |
| Service | `recommendation-service.ts` | `rec.ts`, `rs.ts` | Intention clear; abbreviations hide meaning |
| Utility Function | `validate-image-upload.ts` | `validate.ts` | Specific purpose stated upfront |
| Custom Hook | `use-recommendation.ts` | `useRec.ts`, `hook.ts` | Convention + clarity |
| API Route | `wardrobe-routes.py` | `routes.py` | Context prevents naming collision |
| Test | `auth-service.test.ts` | `authTest.ts`, `auth_test.ts` | Consistent pattern; `.test.ts` is widely recognized |
| Config | `recommendation-config.ts` | `config.ts` | Clarifies which config |
| Constant | `garment-categories.ts` | `categories.ts`, `CATEGORIES.ts` | Avoids generic names |
| Repository | `wardrobe-repository.py` | `repo.py`, `wardrobe_repo.py` | Explicit layer; consistent casing |
| Schema | `recommendation-schema.ts` | `schema.ts`, `rec-schema.ts` | Clear data shape it represents |
| Middleware | `request-lifecycle-middleware.ts` | `middleware.ts` | Specific responsibility |
| Context | `auth-context.tsx` | `AuthContext.tsx`, `context.tsx` | Consistent naming convention |
| Style | `outfit-card-styles.ts` | `styles.ts`, `card.styles.ts` | Scoped to component |

---

## Casing Conventions by Language

### JavaScript/TypeScript
- **Files:** `kebab-case` (all lowercase, dashes)
  - `recommendation-service.ts`
  - `outfit-card.tsx`
  - `validate-image-upload.ts`
  - `use-auth.ts`

- **Exports/Classes:** `PascalCase`
  ```typescript
  // recommendation-service.ts
  export class RecommendationService { }
  
  // outfit-card.tsx
  export const OutfitCard = () => { }
  ```

- **Functions/Variables:** `camelCase`
  ```typescript
  export const getRecommendation = () => { }
  export const itemCategory = 'tops';
  ```

### Python
- **Files:** `snake_case` (all lowercase, underscores)
  - `recommendation_service.py`
  - `wardrobe_repository.py`
  - `validate_image_upload.py`

- **Classes:** `PascalCase`
  ```python
  # recommendation_service.py
  class RecommendationService:
      pass
  ```

- **Functions/Variables:** `snake_case`
  ```python
  def get_recommendation(user_id: str) -> Outfit:
      pass
  
  item_category = 'tops'
  ```

### C#/Java/Kotlin/Swift
- **Files:** `PascalCase` (matching class name)
  - `RecommendationService.kt`
  - `GarmentItem.swift`
  - `WardrobeRepository.cs`

### Go/Rust
- **Files:** `snake_case`
  - `recommendation_service.go`
  - `garment_item.rs`
  - `wardrobe_repository.rs`

### Config & Markup
- **All lowercase with dashes**
  - `docker-compose.yml`
  - `.env.example`
  - `.eslintrc.js`
  - `package.json` (no change; standard)
  - `wrangler.jsonc`

---

## Special Cases

### Test Files
- **Pattern:** `{module}.test.ts` or `{module}.spec.ts`
- **Examples:**
  - `auth-service.test.ts` ✅
  - `recommendation.spec.ts` ✅
  - `authServiceTest.ts` ❌ (inconsistent pattern)
  - `test-auth.ts` ❌ (prefix pattern less common)

### Temporary/Backup Files
- **Prefix with underscore:** `_legacy_home-screen.tsx`
- **Keep original name:** `_HomeScreen.tsx` (pending deletion)
- **Rationale:** Sorted to top of directory; signals "don't use"

### Index Files
- **Standard:** `index.ts`, `index.tsx`
- **Re-export for public API:**
  ```typescript
  // services/index.ts
  export { RecommendationService } from './recommendation-service';
  export { WardrobeService } from './wardrobe-service';
  export { AuthService } from './auth-service';
  
  // Usage: import { RecommendationService } from './services'
  ```

### Environment Files
- **Development:** `.env.local` (git-ignored)
- **Template:** `.env.example` (git-tracked, shows structure)
- **Production:** `.env.production` (CI/CD deployment)

---

## Naming Anti-Patterns to Avoid

| Bad Pattern | Problem | Fix |
|-------------|---------|-----|
| `util.ts`, `helper.ts` | Too vague; unclear what utilities exist | `validate-image-upload.ts`, `format-date.ts` |
| `index.ts` (non-export) | Only use for re-exports | `outfit-card.tsx`, `recommendation-service.ts` |
| `types.ts` (in root) | Should be scoped | `types/navigation.ts`, `types/api.ts` |
| `service.ts`, `repo.ts` | Generic; multiple services exist | `wardrobe-service.ts`, `auth-repository.py` |
| `Component.tsx` | Same name as class; confusing | `outfit-card.tsx` |
| `test.ts` (no module name) | Which module is this testing? | `auth-service.test.ts` |
| `CONSTANTS.ts` | Should clarify domain | `garment-categories.ts`, `http-status-codes.ts` |
| `handlers.ts` | Too broad | `recommendation-handlers.ts`, `error-handlers.ts` |

---

## File Organization Rules

### Grouping by Concern (Preferred)

```
services/
├── auth-service.ts
├── recommendation-service.ts
├── wardrobe-service.ts
└── favorite-service.ts

screens/
├── home-screen.tsx
├── wardrobe-screen.tsx
└── settings-screen.tsx
```

### Not by Type

```
# AVOID THIS
services/
auth/
recommendations/
wardrobe/
favorites/
```

**Rationale:** Feature-based grouping is more maintainable; easier to find all code related to "recommendations" in one place.

---

## Naming Across Tiers (Mobile/Backend/Admin)

### Consistency Across Surfaces

**Problem:** Same concept named differently across platforms = confusion.

```
❌ WRONG - Inconsistent naming
Mobile:   RecommendationCard.tsx
Backend:  outfit_suggestion_route.py
Admin:    OutfitDisplay.tsx

✅ RIGHT - Consistent naming
Mobile:   outfit-card.tsx
Backend:  outfit_route.py (or recommendation_route.py)
Admin:    outfit-card.tsx
```

### Service Naming Convention

All repos follow `{domain}-service`:
- Mobile: `recommendation-service.ts`
- Backend: `recommendation_service.py`
- Admin: `recommendation-service.ts`

---

## Special Characters & Punctuation

**Allowed:** dashes, dots, underscores, numbers

**Avoid:** spaces, special chars (@, #, $, %, &), multiple consecutive dashes

```
✅ Valid:
- wardrobe-item-v2.ts
- auth_service_v1.py
- config.prod.ts
- user-123-data.json

❌ Invalid:
- wardrobe item.ts (space)
- auth@service.ts (special char)
- auth--service.ts (double dash)
- outfit$card.tsx (special char)
- user #123.ts (space + special char)
```

---

## Versioning in Filenames

**When to use version suffixes:**
- Breaking refactors that need side-by-side comparison
- Legacy systems being phased out
- Migration in progress

```
✅ Good:
- _legacy_home-screen.tsx  (pending deletion, marked with underscore)
- wardrobe-service-v2.ts   (new version, old still active)
- recommendation-engine-v05.py (multiple versions in production)

❌ Overuse:
- file-v1.ts, file-v2.ts, file-v3.ts (each version should be explicitly named by feature)
```

---

## Searchability (For LLM Tools)

**Goal:** `grep`, `find`, `Glob` in editors should easily discover files.

```bash
# Good: Clear patterns
grep -r "recommendation-service" src/

# Bad: Ambiguous
grep -r "service" src/  # Returns 200+ results

# Good: Specific intent
find . -name "*validate-*.ts"

# Bad: Too broad
find . -name "*util*"
```

---

## File Size Naming Convention

**When split into multiple files:**

Use descriptive subtopic names, not numbers.

```
✅ Preferred:
components/
├── outfit-card.tsx
├── outfit-card-header.tsx
├── outfit-card-actions.tsx
└── outfit-card-footer.tsx

❌ Avoid:
components/
├── outfit-card.tsx
├── outfit-card-1.tsx
├── outfit-card-2.tsx
└── outfit-card-3.tsx
```

**Rationale:** When a developer needs to edit "the button section," they can search for "actions" and find the right file.
