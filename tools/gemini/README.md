# Gemini Asset Pipeline

## Purpose

Generate consistent visual assets for all app modules from one manifest and one style profile.

## Inputs

1. `assets/manifest/asset_manifest_v1.json`
2. `tools/gemini/style_system.json`
3. `GEMINI_API_KEY` environment variable

## Output

Generated files under:

`generated/assets/...`

## Commands

Generate all:

```bash
python3 tools/gemini/generate_assets.py \
  --manifest assets/manifest/asset_manifest_v1.json \
  --style tools/gemini/style_system.json \
  --out generated/assets
```

Only images:

```bash
python3 tools/gemini/generate_assets.py \
  --manifest assets/manifest/asset_manifest_v1.json \
  --style tools/gemini/style_system.json \
  --out generated/assets \
  --kinds image
```

Only video/lottie specs:

```bash
python3 tools/gemini/generate_assets.py \
  --manifest assets/manifest/asset_manifest_v1.json \
  --style tools/gemini/style_system.json \
  --out generated/assets \
  --kinds storyboard lottie_spec
```

## Notes

1. If the model returns no inline image, the script stores model text output as fallback.
2. Use generated storyboard specs to create final MP4 clips with your motion pipeline.
3. Keep one style profile for all modules to avoid visual drift.

