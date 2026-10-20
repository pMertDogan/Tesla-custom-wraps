# Tesla Wrap Studio

AI-powered Tesla custom wrap designer. Describe a wrap, generate it with a
text-to-image model, clip it to the real body panel layout and export a file
the car accepts.

Built on top of the official [`teslamotors/custom-wraps`](https://github.com/teslamotors/custom-wraps)
templates.

---

## What it does

1. **Pick a vehicle** — all 12 models Tesla publishes a wrap template for
   (Cybertruck, Model 3, Model S, Model X, Model Y and their trims).
2. **Describe the design** — a free text prompt plus a style preset
   (digital camo, gradient mesh, retro stripes, pixel art, …).
3. **Generate** — the app sends the prompt *and* Tesla's UV template to the AI
   provider, so the artwork lands on the right panels.
4. **Clip to the panels** — the result is masked against the template so the
   body panels carry the artwork and the shut lines stay clean.
5. **Export** — a PNG that satisfies every requirement of Tesla's Paint Shop.

## Requirements

- Flutter 3.47 or newer (Dart 3.11+)
- An API key for one of the supported providers

## Getting started

```bash
flutter pub get
flutter run -d chrome          # or: flutter run -d web-server
```

The app is a Flutter **web** app. It also compiles for mobile and desktop,
the asset layout is platform independent.

## AI providers

Open **Settings** from the home or the studio and pick a provider:

| Provider | Model | Reference image |
| --- | --- | --- |
| Gemini 3 Pro Image | `gemini-3-pro-image` | yes |
| Gemini Nano Banana 2.1 | `gemini-nano-banana-2.1` | yes |
| Gemini 2.5 Flash Image | `gemini-2.5-flash-image` | yes |
| Gemini 3.1 Flash Image | `gemini-3.1-flash-image` | yes |
| OpenAI gpt-image-1 | `gpt-image-1` | no |
| OpenAI DALL-E 3 | `dall-e-3` | no |
| Custom OpenAI-compatible | your own | no |

The Gemini models receive Tesla's UV template as a reference image, which is
what keeps the artwork aligned with the real panels. OpenAI-compatible
providers receive the layout described in text only.

The **Custom OpenAI-compatible** option points the studio at any gateway that
speaks the OpenAI images API (LiteLLM, OpenRouter, a local proxy). Set the
base URL and the model name in Settings.

The API key stays in memory for the session unless you tick *Remember this key
on this device*.

## How a wrap is built

```
prompt ─┐
         ├─► WrapPromptBuilder ─► AI provider ─┐
template ┘   (wrap contract)     (image)       ├─► panel mask ─► export
                                                 │
                            crop to template aspect ┘
```

- **WrapPromptBuilder** spells out the output contract: a flat 2D texture
  atlas, no car, no background, no text, flat colour, full bleed.
- **TemplateMasker** derives a panel mask from the template by flooding the
  white background from the image border. Whatever the flood cannot reach is
  inside a closed panel outline and therefore paintable.
- **WrapExporter** crops the design to the template aspect, scales it, applies
  the mask and shrinks the PNG until it fits the 1 MB budget.

## Tesla's requirements

The exported file obeys all of them:

| Rule | Value |
| --- | --- |
| Format | PNG |
| Size | 512 x 512 to 1024 x 1024 px |
| File size | max 1 MB |
| File name | max 30 characters, `A-Z a-z 0-9 _ -` and spaces only |

### Installing the wrap on the car

- **Mobile app** (v4.59.0+): Creations → Wrap → Upload
- **USB stick**: format the drive as exFAT or FAT32 (NTFS is not supported),
  create a `Wraps` folder in the root and copy the PNG files in. The stick
  must not contain map or firmware updates.
- In the car: Toybox → Paint Shop → Wraps

## Project structure

```
lib/
  core/theme.dart              colours and the dark theme
  models/
    ai_provider.dart            provider catalog
    ai_settings.dart            user configurable settings
    tesla_model.dart            vehicle metadata
    wrap_design.dart            a generated design
  screens/
    gallery_page.dart           Tesla's example designs
    home_page.dart              landing page
    studio_page.dart            the design screen
  services/
    ai_service.dart             real provider calls
    export_service.dart         Tesla compliant PNG export
    prompt_builder.dart         prompt contract and style presets
    settings_service.dart       persistence
    template_masker.dart        panel mask extraction
    vehicle_service.dart        the 12 vehicles
  state/
    app_scope.dart              InheritedNotifier scope
    app_state.dart              settings and session history
  widgets/
    settings_dialog.dart        provider configuration
```

## Tests

```bash
flutter test
```

The suite covers the prompt contract, the exporter (naming, size budget,
masking), the panel mask against the real Tesla templates, the provider
catalog on disk and the AI service against a mocked HTTP client.

## Roadmap

- **3D preview** — the GLB vehicle models are already wired into the catalog
  (`assets/models/`), the studio keeps the camera azimuth ready for it.
- Manual editing tools (draw, text, logo, layers) — the sidebar already
  carries the entry points.
- Material controls (metallic, roughness) — they belong to the 3D preview.

## License

The templates and example designs are from
[`teslamotors/custom-wraps`](https://github.com/teslamotors/custom-wraps).
The application code in this repository is MIT licensed.
