# General Principles & Philosophy

Core development principles that apply across all Auxi repositories.

---

## YAGNI — You Aren't Gonna Need It

**Principle:** Don't build features, abstractions, or infrastructure "just in case."

**Application:**
- Don't add a database migration framework until you have 3+ migrations
- Don't abstract a utility until it's used in 2+ places
- Don't optimize for scale until you hit actual scale problems
- Build for today's requirements; refactor tomorrow when patterns emerge

**Example — Mobile:**
```typescript
// WRONG - Over-engineering
// "We might need multi-language support"
const messages = {
  welcome: 'Welcome',
  submitLabel: 'Submit'
};

// RIGHT - Add i18n when you actually need it
<Text>{t('welcome')}</Text>  // Only after requirements specify language support
```

---

## KISS — Keep It Simple, Stupid

**Principle:** Clarity beats cleverness. A junior dev should understand your code without 20 minutes of study.

**Application:**
- Prefer explicit variable names over cryptic abbreviations
- Prefer simple if/else over ternary chains
- Prefer documented functions over "obvious" behavior
- Prefer boring solutions over clever ones

**Example — Backend:**
```python
# WRONG - Too clever
def get_recs(uid, ctx):
    return [o for o in engine(uid, **ctx) if o not in recent_ids(uid)]

# RIGHT - Clear intent
def get_recommendations(user_id: str, context: dict) -> List[Outfit]:
    """Get outfit recommendations, excluding recently shown outfits."""
    outfit_recommendations = engine.generate(user_id, **context)
    recent_outfit_ids = get_recently_shown_outfit_ids(user_id)
    return [o for o in outfit_recommendations if o.id not in recent_outfit_ids]
```

---

## DRY — Don't Repeat Yourself

**Principle:** Extract repeated patterns into reusable, single-source-of-truth modules.

**When to Extract:**
- Same code appears in 2+ files → Extract to shared utility
- Same pattern appears 3+ times → Extract to base class or helper
- Configuration repeated across modules → Centralize in config file

**Example — Mobile:**
```typescript
// WRONG - Repeated in 3 components
const handleError = (error: Error) => {
  logger.error('Request failed', error);
  showAlert('Something went wrong');
};

// RIGHT - Extract to custom hook
export const useErrorHandler = () => {
  return (error: Error) => {
    logger.error('Request failed', error);
    showAlert('Something went wrong');
  };
};

// In components:
const { handleError } = useErrorHandler();
```

---

## File Size Management

**Rule:** Keep individual code files under 200 lines (comments + code).

**Rationale:**
- Easier to understand in one screen view
- Easier to test (smaller surface area)
- Reduces cognitive load
- Forces focus on single responsibility

**When a File Gets Large:**

1. **Identify sub-responsibilities** — What distinct concerns exist?
2. **Extract to separate modules** — Create focused files for each concern
3. **Re-import for backward compatibility** — Old file can re-export from new modules

**Example — Mobile Component Split:**

```typescript
// ❌ WRONG - One 250-line file
// HomeScreen.tsx (250 lines)
// ├─ Render logic
// ├─ Recommendation fetch
// ├─ Filter/sort UI
// ├─ Context chip rendering
// └─ Action button handlers

// ✅ RIGHT - Modular structure
// HomeScreen.tsx (80 lines) - Main component, orchestration
// ├─ useRecommendation.ts (40 lines) - Data fetching
// ├─ RecommendationCard.tsx (50 lines) - Card display
// ├─ ContextChips.tsx (40 lines) - Context UI
// └─ ActionButtons.tsx (30 lines) - Actions
```

---

## Code Quality Principles

### Readability Over Brevity

```typescript
// WRONG
const f = (i: WI[]) => i.filter(x => x.c === 'tops' && x.f === 'M');

// RIGHT
const getWomensTopItems = (items: WardrobeItem[]) => 
  items.filter(item => item.category === 'tops' && item.fit === 'M');
```

### Explicit Over Implicit

```python
# WRONG
def process(d):
    if d.get('email'):  # Implicit: what if 'email' is missing?
        return d
    return None

# RIGHT
def process_user_registration(data: dict) -> Optional[dict]:
    """Process user registration data.
    
    Args:
        data: User registration form data.
    
    Returns:
        Validated data or None if email is missing.
    """
    email = data.get('email')
    if not email:
        logger.warning("Registration data missing email")
        return None
    return data
```

### Type Safety

**All repos:**
- **TypeScript:** `strict: true` in tsconfig.json
- **Python:** Full type hints on all public functions
- **No `any` without explanation**

```typescript
// WRONG
const processItem = (item: any) => {
  return item.category;
};

// RIGHT
interface WardrobeItem {
  id: string;
  category: 'tops' | 'bottoms' | 'shoes' | 'accessories';
  color: string;
}

const getItemCategory = (item: WardrobeItem): string => {
  return item.category;
};
```

---

## Error Handling Philosophy

**Principle:** Fail fast, log clearly, return useful errors to users.

```typescript
// WRONG - Silent failure
const getRecommendation = async (userId: string) => {
  try {
    return await apiClient.get(`/recommendation?user=${userId}`);
  } catch (e) {
    return null;  // User sees nothing; debugging impossible
  }
};

// RIGHT - Clear error handling
const getRecommendation = async (userId: string): Promise<Outfit> => {
  try {
    if (!userId) throw new Error("userId required");
    return await apiClient.get(`/recommendation?user=${userId}`);
  } catch (error) {
    logger.error('Recommendation fetch failed', {
      userId,
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined
    });
    throw new RecommendationError("Failed to get recommendation");
  }
};
```

---

## Testing Philosophy

**Principle:** Tests verify behavior, not implementation. Write tests that would still pass if you refactor the code.

```typescript
// WRONG - Tests implementation details
it('calls filterByCategory function', () => {
  const spy = jest.spyOn(utils, 'filterByCategory');
  getOutfit(items);
  expect(spy).toHaveBeenCalled();
});

// RIGHT - Tests behavior
it('returns outfit with only tops and bottoms', () => {
  const outfit = getOutfit(items);
  expect(outfit.every(item => ['tops', 'bottoms'].includes(item.category))).toBe(true);
});
```

---

## Performance Mindset

**Don't optimize prematurely, but don't ignore obvious inefficiencies.**

**React Mobile:**
- Memoize expensive renders (React.memo)
- Use useCallback for stable function references
- Lazy-load screens with React Navigation
- Monitor render cycles with React DevTools Profiler

**FastAPI Backend:**
- Target <8s p95 for recommendation endpoint
- Cache with Redis (1-hour TTL)
- Use connection pooling (built-in to SQLAlchemy)
- Paginate list endpoints (20 items default)

**React Admin:**
- Virtualize long lists (react-window for 1000+ items)
- Batch API requests (load data once, not per row)
- Debounce search/filter inputs

---

## Documentation Standards

**Every public function/class should have a docstring.**

```typescript
// CORRECT - Clear, concise
/**
 * Generate outfit recommendation based on user's wardrobe and context.
 * 
 * @param userId - User's unique identifier
 * @param context - Recommendation context (occasion, weather, time)
 * @returns Outfit object with items and explanation
 * @throws {RecommendationError} If user has insufficient wardrobe items
 */
export const getRecommendation = async (userId: string, context: Context): Promise<Outfit> => {
  // implementation
};

// WRONG - Missing details
const getRecommendation = async (userId, context) => {
  // Gets a recommendation
};
```

```python
# CORRECT - Google style docstring
def get_recommendations(user_id: str, context: dict) -> List[Outfit]:
    """Generate outfit recommendations for user.
    
    Args:
        user_id: User's unique identifier.
        context: Dict with keys 'occasion', 'weather', 'time' (all optional).
    
    Returns:
        List of Outfit objects sorted by confidence score (highest first).
    
    Raises:
        UserNotFoundError: If user_id doesn't exist.
        InsufficientWardrobeError: If user has <3 items.
    """
    # implementation

# WRONG - Missing documentation
def get_recommendations(user_id, context):
    # Gets recommendations
    pass
```

---

## When to Break These Rules

**These principles are guidelines, not absolute laws.**

- **Performance crisis?** Optimize first, refactor after
- **External library convention conflicts?** Follow library conventions
- **Prototype/MVP deadline?** Ship first, polish later
- **Team consensus differs?** Align as team; consistency matters more than perfection

**But always:**
- Document why you broke the rule (comment or commit message)
- Plan to fix it (add to technical debt list or Linear)
- Don't let it spread to other files
