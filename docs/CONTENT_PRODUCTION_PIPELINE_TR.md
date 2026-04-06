# Visual and Video Content Production Pipeline

## 1) Target

Create a consistent visual language across all app modules (all files/screens),
not only menu pages.

## 2) Style Lock

1. One fixed style profile in `tools/gemini/style_system.json`.
2. One prompt template with hard constraints:
   - same color system
   - same icon style
   - same character style
   - same shadows and background treatment
3. Quality gate:
   - reject if style drift is detected.

Reference tuning (2026-02-27):

1. Keep high-white-space layout and soft card structure.
2. Use purple accent mainly for primary CTA / selected state.
3. Prefer segmented controls, rounded pills, and clean empty-state hierarchy.

## 3) Asset Types

1. Core illustrations (heroes, empty states, module cards).
2. UI support icons.
3. Storyboard specs for short videos.
4. Lottie animation specs for in-app loops.

## 4) Production Stages

1. Manifest planning
2. Generation
3. Human QA
4. Naming/versioning
5. App integration
6. Regression visual checks

## 5) Naming Standard

`{module}/{screen}_{state}_{variant}.{ext}`

Examples:

1. `feeding/empty_state_default.png`
2. `sleep/hero_night_default.png`
3. `premium/paywall_family_v2.png`

## 6) Video Plan

Use video only where it increases understanding:

1. onboarding feature walkthrough
2. chronic-care emergency card flow
3. doctor-sharing flow

Keep clips short:

1. 6-12 sec looping clips for app
2. 15-30 sec for store previews

## 7) QA Checklist

1. Style consistency
2. Cultural neutrality for TR/US/UK/DE
3. No medical misinformation
4. No copyrighted external characters
5. Correct language/localization spacing
