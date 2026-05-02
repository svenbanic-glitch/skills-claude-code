---
name: sina_image_fluxklein
description: Generate Sina images using Flux Klein 9B. Use for Flux aesthetics, ReferenceLatent workflows, sinafluxneu LoRA. Triggers - "flux", "flux klein", "fluxneu", "klein 9b".
tools: Bash, Read, Write
---

# sina_image_fluxklein

Flux Klein 9B Sina pipeline. Reference: `ClaudeCode (FluxKlein Image Subtitle Remove WF).json` (copy at `reference_workflow.json`). Compact ReferenceLatent-based editing workflow — load source image, encode to latent, condition on prompt, regenerate with Flux Klein.

21 nodes, 18 active. Designed for image editing (subtitle removal, tattoo addition, face swap, prompt-driven re-render) rather than from-scratch generation.

## When to use
- User explicitly asks for Flux / Flux Klein aesthetic
- Image-to-image editing scenarios (modify existing image with prompt)
- Subtitle/watermark removal
- Tattoo/artifact stamping with Flux precision
- When `sinafluxneu` or `sina fluxklein base 9B` LoRAs are needed

## Pipeline stages

```
[CLIPLoader qwen_3_8b_fp8mixed flux2]   [VAELoader flux2-vae]   [UNETLoader flux-2-klein-9b]
        │                                     │                            │
        ▼                                                                   ▼
[CLIPTextEncode positive (prompt)]                                    [Optional LoraLoaderModelOnly chain]
[CLIPTextEncode negative (empty)]                                            │
        │                                                                    ▼
        ▼                                                            [LoRA-injected MODEL]
                            ┌───────────────────────────────────────┘
                            │
[LoadImage source] → [VAEEncode] → [ReferenceLatent] ────┐
                                                          ▼
                                                  [KSampler]
                                                  uni_pc / normal / 4 steps / cfg 1
                                                          │
                                                          ▼
                                                  [VAEDecode]
                                                          │
                                                          ▼
                                                  [SaveImage]
```

## Required models

| Slot | File | Notes |
|---|---|---|
| UNet | `flux-2-klein-9b.safetensors` | in `/models/diffusion_models/` |
| CLIP | `qwen_3_8b_fp8mixed.safetensors` (type=`flux2`) | in `/models/text_encoders/` |
| VAE | `flux2-vae.safetensors` | Flux 2 VAE — different from `ae.safetensors`! |

Weight dtype: `fp8_e4m3fn_fast` for VRAM efficiency on L4.

## Active LoRAs (Sina + style)

Sina Flux Klein LoRAs in `/loras/`:
- `sina fluxklein base 9B_000001300.safetensors` ← **highest epoch**
- `sina fluxklein base 9B_000001200.safetensors`
- `sinafluxneu_000000800.safetensors` ← also commonly used
- `sinafluxneu_000000700.safetensors`

Style/quality LoRAs (Flux Klein 9B):
- `SEXGOD_ImprovedNudity_Klein9b_v2_5.safetensors` — NSFW polish
- `SEXGOD_SexySelfies_Klein9b_v1.safetensors` — selfie aesthetic
- `lenovo_flux_klein9b.safetensors` — body aesthetic
- `nicegirls_flux_klein9b.safetensors` — face polish
- `pusfix-klein.safetensors` — pussy detail fix
- `cameltoe_klein.safetensors` — anatomy detail
- `igbaddie-klein.safetensors` — Instagram baddie aesthetic
- `klein_snofs_v1_1/_2.safetensors` — snofs style
- `bfs_head_v1_flux-klein_9b_step3500_rank128.safetensors` — face/head specialist
- `Flux Klein - NSFW v2.safetensors` — base NSFW
- `NSFWFLUXKLEIN-Unchained-V2.safetensors` — uncensored
- `FluxK4Play.v1.safetensors` — play aesthetic
- `FLUXklein_slider_anatomy.safetensors` — anatomy slider

Trigger word: `sinahohenheim` (Flux Klein Sina LoRAs use the same trigger as Z-Image).

## ReferenceLatent pattern (key technique)

The reference workflow is an **edit pipeline**, not a from-scratch generator:
1. `LoadImage` reads source
2. `ImageScaleToTotalPixels` normalizes to ~1MP
3. `VAEEncode` → `ReferenceLatent` injects source structure into the conditioning
4. `KSampler` re-renders with prompt guidance against the latent

For from-scratch generation: use `EmptyLatentImage` instead of `VAEEncode → ReferenceLatent`, set denoise to 1.0.

For style transfer / heavy edit: keep `ReferenceLatent` but increase denoise to 0.85+.
For light edit (subtitle removal): keep denoise at 1.0 with full `ReferenceLatent` weight.

## Default parameters

| Param | Value | Notes |
|---|---|---|
| Resolution | 1024 × 1328 (portrait) | EmptyLatentImage when not editing |
| Sampler | `uni_pc` | also `dpmpp_2m_sde`, `euler` work |
| Scheduler | `normal` | also `simple`, `karras` |
| Steps | 4 | very fast — Flux Klein is distilled |
| CFG | 1.0 | Flux Klein expects CFG ≈ 1 (real CFG via TrueCFG patch if needed) |
| Denoise | 1.0 | full diffusion |

**Speed:** ~3–5s/image on L4 at 1024×1328 with 4 steps and 1–2 LoRAs.

## Variable inputs (per run)

| What | Where | Notes |
|---|---|---|
| Source image | LoadImage 13 `image` | filename relative to `/input/` |
| Positive prompt | CLIPTextEncode 7 `text` | scene description |
| Negative prompt | CLIPTextEncode 8 `text` | typically empty for Flux |
| Resolution | EmptyLatentImage 5 `width`/`height` | 1024×1328 default |
| Seed | KSampler 9 `seed` | randomize for variety |
| LoRAs | LoraLoaderModelOnly nodes | toggle by enabling/bypassing |

## Code skeleton

```python
import json, copy, urllib.request, uuid, time, datetime, random

REF = "/workspace/.claude/skills/sina_image_fluxklein/reference_workflow.json"
HOST = "http://localhost:8188"

def submit(prompt: str, *, source_image: str = None, seed: int = None,
           sina_lora: str = "sina fluxklein base 9B_000001300.safetensors") -> str:
    with open(REF) as f:
        wf = json.load(f)  # assumes API format
    if seed is None: seed = random.randint(0, 2**31)

    for nid, node in wf.items():
        ct = node.get("class_type")
        inp = node.get("inputs", {})
        if ct == "CLIPTextEncode" and inp.get("text","") and "the woman" in inp.get("text","").lower():
            inp["text"] = prompt  # heuristic for the active positive prompt
        if ct == "LoadImage" and source_image:
            inp["image"] = source_image
        if ct == "KSampler":
            inp["seed"] = seed
        if ct == "LoraLoaderModelOnly" and "fluxklein" in inp.get("lora_name","").lower():
            inp["lora_name"] = sina_lora
        if ct == "SaveImage":
            inp["filename_prefix"] = f"{datetime.date.today():%Y%m%d}_fluxklein"

    payload = {"prompt": wf, "client_id": str(uuid.uuid4())}
    req = urllib.request.Request(f"{HOST}/prompt",
                                 data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)["prompt_id"]
```

## Alternative donor workflows

- `Sven QWEN IMAGE UNLEASHED EDIT Pics.json` — same Flux Klein pipeline with 4 active Sina-related LoRAs (sina fluxklein base 9B + SEXGOD + lenovo_flux_klein9b + pusfix-klein)
- `Flux2 Klein 9b Face Swap.json` — face-swap variant
- `Flux2 Klein 9b Inpainting.json` — inpainting variant
- `flux2-klein-editing+face swap.json` — editing + face swap combo
- `Sven I2I Fluxklein Character Replace Image Top.json` — character replacement
- `Image Klein (nude)Sina_Undressing_Workflow_v3_1_NoUltraReal.json` — undressing scene
- `Image Klein NSFw für Wan videos.json` — Klein i2v prep for WAN
- `Z Image and flux klein.json` — hybrid Z-Image + Flux Klein

For full multi-LoRA Sina Flux setup: load `Sven QWEN IMAGE UNLEASHED EDIT Pics.json` as starting point.

## Common Pitfalls
_(empty — populate with experience. Likely candidates: VAE confusion (`flux2-vae.safetensors` vs `ae.safetensors` — Flux 1 vs Flux 2 VAE are NOT interchangeable), `qwen_3_8b_fp8mixed` CLIP type must be `flux2` not `flux` (Flux 1 uses `clip_l + t5xxl`), Flux Klein expects CFG=1 — higher values produce washed-out artifacts, ReferenceLatent without source image fails silently, "Klein" name confusion with naming alternative checkpoints)_
