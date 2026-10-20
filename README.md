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

| Provider | Model | Reference image | Cost |
| --- | --- | --- | --- |
| Cloudflare FLUX 2 dev | `@cf/black-forest-labs/flux-2-dev` | yes | free daily allowance |
| Cloudflare FLUX 2 Klein 9B | `@cf/black-forest-labs/flux-2-klein-9b` | yes | free daily allowance |
| Cloudflare FLUX 2 Klein 4B | `@cf/black-forest-labs/flux-2-klein-4b` | yes | free daily allowance |
| Cloudflare FLUX 1 schnell | `@cf/black-forest-labs/flux-1-schnell` | no | free daily allowance |
| Gemini 3 Pro Image | `gemini-3-pro-image` | yes | paid |
| Gemini Nano Banana 2.1 | `gemini-nano-banana-2.1` | yes | paid |
| Gemini 2.5 Flash Image | `gemini-2.5-flash-image` | yes | paid |
| Gemini 3.1 Flash Image | `gemini-3.1-flash-image` | yes | paid |
| OpenRouter FLUX 3 Klein | `black-forest-labs/flux-3-image-klein` | yes | about \$0.009 per image |
| OpenRouter Qwen Image 2.1 Turbo | `qwen/qwen-image-2.1-turbo` | yes | about \$0.018 per image |
| OpenRouter Nano Banana 2.1 | `google/gemini-nano-banana-2.1` | yes | about \$0.04 per image |
| OpenRouter Gemini 3 Pro Image | `google/gemini-3-pro-image` | yes | about \$0.13 per image |
| OpenAI gpt-image-1 | `gpt-image-1` | no | paid |
| OpenAI DALL-E 3 | `dall-e-3` | no | paid |
| Custom OpenAI-compatible | your own | no | depends |

The Gemini, OpenRouter and FLUX 2 models receive Tesla's UV template as a
reference image, which is what keeps the artwork aligned with the real
panels. The OpenAI-compatible providers receive the layout described in text
only.

The **Custom OpenAI-compatible** option points the studio at any gateway that
speaks the OpenAI images API (LiteLLM, a local proxy). Set the base URL and
the model name in Settings.

### Cloudflare Workers AI (the free one)

Cloudflare gives every account **10,000 free neurons a day**, and no card is
needed. That is the only way to design a wrap without paying.

Create a token at <https://dash.cloudflare.com/profile/api-tokens> with the
**Workers AI** permission, then in Settings:

- **API key**: the token
- **Base URL**: `https://api.cloudflare.com/client/v4/accounts/<account id>/ai/run`
  (the account id is in the Cloudflare dashboard sidebar)
- **Model**: `@cf/black-forest-labs/flux-2-klein-4b` for the most wraps a day,
  or `@cf/black-forest-labs/flux-2-dev` for the strongest one

How many wraps a day that buys, at the 1024x1024 tier the studio asks for:

| Model | Neurons per image | Images per day | Reference image |
| --- | --- | --- | --- |
| `@cf/black-forest-labs/flux-2-klein-4b` | about 130 | about 75 | yes |
| `@cf/black-forest-labs/flux-1-schnell` | about 58 | about 170 | no, text only |
| `@cf/black-forest-labs/flux-2-dev` | about 900 | about 11 | yes |
| `@cf/black-forest-labs/flux-2-klein-9b` | about 1,545 | about 6 | yes |

The allowance is 10,000 neurons **for the whole account, shared by every
model**, and it resets at 00:00 UTC. The studio shows the neuron count of
every generation, so the real cost is always visible. A rejected request
never consumes neurons.

Cloudflare bills the same neurons after the free allowance runs out, at
\$0.011 per 1,000 neurons, which is about \$0.01 for another FLUX 2 dev
wrap. The **Workers Paid** plan starts at \$5 a month and still includes
the same 10,000 free neurons a day.

#### Request body shapes

Workers AI models do not agree on how a request looks, and the studio sends
what each one wants:

- The **FLUX 2** models only accept a multipart form, where the UV template
  travels as a file and the prompt as a field. They are picky about the
  optional fields, so the studio falls back from the full body to a shorter
  one and finally to a prompt-only body.
- **FLUX 1 schnell** only accepts JSON, and it wants the step count as an
  integer. A string is rejected, and so are `num_steps`, `seed`, `width` and
  `height`.

#### Cloudflare in the browser build

Cloudflare's AI endpoint answers `405` to the CORS preflight that a browser
sends before a multipart request with an `Authorization` header. The mobile
and desktop builds talk to it directly, but the **web build cannot** — the
request never leaves the browser. The studio says so instead of pretending
the network is down.

If you need the web build, put a small Worker in front of it and paste the
Worker URL into the base URL field as `https://<worker>.workers.dev/proxy`.
The Worker forwards the request and the token, and adds the CORS headers the
browser needs:

```js
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export default {
  async fetch(request, env) {
    // The browser sends a preflight before the multipart POST.
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }

    // /proxy/@cf/black-forest-labs/flux-2-dev -> the Cloudflare AI endpoint.
    const model = new URL(request.url).pathname.replace(/^\/proxy/, '');
    const target =
      `https://api.cloudflare.com/client/v4/accounts/${env.ACCOUNT_ID}` +
      `/ai/run${model}`;

    const upstream = await fetch(target, {
      method: 'POST',
      headers: {
        // The studio already sends the token in this header.
        Authorization: request.headers.get('authorization') || '',
        'Content-Type': request.headers.get('content-type') || '',
      },
      body: await request.arrayBuffer(),
    });

    return new Response(upstream.body, {
      status: upstream.status,
      headers: {
        ...cors,
        'Content-Type':
          upstream.headers.get('content-type') || 'application/json',
      },
    });
  },
};
```

Set `ACCOUNT_ID` as a Worker secret or variable. The key never has to be
embedded in the Worker: the studio sends it in the `Authorization` header and
the Worker passes it straight through.

### OpenRouter

OpenRouter is a first-class provider, not a "custom" one, because it speaks a
different dialect: the studio posts to `POST https://openrouter.ai/api/v1/images`
and hands the UV template over as an `input_references` entry, so the layout
survives even for models that never see a text description of it. The template's
own aspect ratio (`4:3`, `1:1`, …) is sent as `aspect_ratio`; if a model
rejects that ratio the request is retried once without it and the exporter
crops to the template.

Get a key at <https://openrouter.ai/keys> and put it in the API key field.

**OpenRouter has no free image models.** The `:free` tier covers text models
only, so image generation always draws on the account balance. Prices are per
image and start low:

| Model | Price per image |
| --- | --- |
| `black-forest-labs/flux-3-image-klein` | about \$0.008 |
| `qwen/qwen-image-2.1-turbo` | about \$0.018 |
| `google/gemini-nano-banana-2.1` | about \$0.04 |
| `google/gemini-3-pro-image` | about \$0.13 |

A failed generation is not billed, so a rejected prompt costs nothing.

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

## Command line

The same pipeline runs headless, which is handy for checking a key or
producing a wrap in a script:

```bash
# generate a wrap with a provider
OPENROUTER_API_KEY=sk-or-... \
  dart run tool/generate_wrap.dart \
    --model model3-2024-base \
    --provider openrouter-flux-3-image-klein \
    --prompt "midnight blue carbon fibre with cyan racing stripes" \
    --out build/wraps/

# run an existing image through crop, mask and export (no credits spent)
dart run tool/generate_wrap.dart \
  --model model3-2024-base \
  --from model3-2024-base/example/Sakura.png \
  --name sakura_pipeline \
  --out build/wraps/
```

| Option | Meaning |
| --- | --- |
| `--model` | Vehicle id, for example `model3-2024-base` |
| `--provider` | Provider id, for example `openrouter-flux-3-image-klein` |
| `--model-id` | Override the provider model |
| `--base-url` | Override the provider base URL |
| `--prompt` / `--style` | Design description and style preset |
| `--from` | Process an existing image instead of generating one |
| `--name` / `--out` | Output file name and directory |

The key is read from `GEMINI_API_KEY`, `OPENAI_API_KEY`,
`OPENROUTER_API_KEY` or `CLOUDFLARE_API_TOKEN`, depending on the provider.
`WRAP_API_KEY` overrides all of them.

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
