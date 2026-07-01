# App Store Screenshot Renderer

This renderer wraps immutable simulator screenshots from `screenshots/demo-*.png`
in App Store-ready marketing artwork. The app UI screenshots are never edited;
they are placed as image layers inside an HTML/CSS device frame.

## Render

```bash
npm --prefix marketing/appstore install
npm --prefix marketing/appstore run render
```

Outputs are written to:

```text
screenshots/appstore/
```

## Edit copy or styling

- `shots.json` controls titles, subtitles, badges, source screenshots, and colors.
- `template.html` controls the visual system: background, typography, frame, shadows,
  and callouts.

Keep final output at `1320x2868` for the 6.9-inch iPhone App Store screenshot slot.
