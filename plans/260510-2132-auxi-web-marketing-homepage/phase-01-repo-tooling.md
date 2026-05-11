---
phase: 1
title: "Repo & Tooling"
status: pending
priority: P1
effort: "2h"
dependencies: []
---

# Phase 1: Repo & Tooling

## Overview
Create the `auxi-web/` directory with a clean Astro + TypeScript + Tailwind
setup, repo hygiene (gitignore, prettier, README skeleton), and a working
`pnpm dev` / `pnpm build`. No content yet — just the shell.

## Requirements
- **Functional:** scaffold builds and serves a placeholder index page.
- **Non-functional:** strict TS, Tailwind JIT, Prettier with Astro plugin,
  no ESLint warnings on fresh scaffold.

## Architecture
```
auxi-web/
├── src/
│   ├── pages/
│   │   └── index.astro       # placeholder
│   ├── layouts/
│   │   └── BaseLayout.astro  # html shell, meta slot
│   └── styles/
│       └── global.css        # tailwind directives
├── public/
│   └── favicon.svg
├── astro.config.mjs
├── tailwind.config.mjs
├── tsconfig.json             # strict, paths: { "~/*": ["src/*"] }
├── package.json              # pnpm, scripts: dev/build/preview/format
├── .prettierrc.mjs           # with prettier-plugin-astro + tailwind
├── .gitignore
└── README.md                 # quick start only; deploy doc lands in phase 5
```

## Related Code Files
- Create: everything above (whole `auxi-web/` directory).
- Modify: none in `auxi/` or `wardrobe-backend/`.
- Modify (umbrella): `/Users/nguyenminhduc/Desktop/wardrobe_project/.gitignore`
  if needed — confirm `auxi-web/node_modules/` and `auxi-web/dist/` excluded.

## Implementation Steps
1. `cd /Users/nguyenminhduc/Desktop/wardrobe_project && mkdir auxi-web && cd auxi-web`
2. `pnpm create astro@latest .` — choose **Empty**, **Yes** TS strict, **No** install deps yet, **No** git (we'll init manually).
3. `pnpm add -D tailwindcss@^3 @astrojs/tailwind prettier prettier-plugin-astro prettier-plugin-tailwindcss`
4. `pnpm dlx astro add tailwind` (auto-wires config + global.css).
5. Write `.prettierrc.mjs` with both plugins; `tailwindFunctions: ["clsx","cn"]`.
6. Write minimal `BaseLayout.astro` (lang=en, charset, viewport, slot for `<title>`, slot for body).
7. Strip default Astro starter content from `index.astro`; replace with `<BaseLayout title="Auxi">Hello</BaseLayout>`.
8. Write README with: `pnpm install`, `pnpm dev`, `pnpm build`, `pnpm preview`.
9. `git init && git add . && git commit -m "chore: scaffold auxi-web"`.
10. Verify: `pnpm dev` serves `http://localhost:4321` with the placeholder.
11. Verify: `pnpm build` produces `dist/` with index.html.

## Success Criteria
- [ ] `auxi-web/` exists with the structure above.
- [ ] `pnpm dev` runs; browser shows placeholder.
- [ ] `pnpm build` succeeds, dist/ contains static html + css.
- [ ] `pnpm exec prettier --check .` passes.
- [ ] `pnpm exec tsc --noEmit` passes (Astro emits .astro types via `astro check` instead — run that too).
- [ ] Initial commit pushed to local repo (no remote yet).

## Risk Assessment
- **Astro version drift:** pin Astro 4.x in package.json; 5.x has breaking
  config changes. Mitigation: use `pnpm create astro@^4`.
- **pnpm vs yarn confusion:** umbrella uses yarn for `auxi/` and pnpm for
  `wardrobe-admin`. Pick pnpm here for consistency with the other web SPA
  and document in README so contributors don't `yarn install` by mistake.
