---
name: sina_image_sdxl
description: Generate Sina images using SDXL pipeline. Use for SDXL aesthetics, illustriousRealism, juggernautXL, lustifySDXLNSFW. Triggers - "SDXL", "illustrious", "juggernaut", "lustify", "sdxl image", "epicrealism".
tools: Bash, Read, Write
---

# sina_image_sdxl

SDXL Sina pipeline. Reference: `Image SDXL lustify8-non-dmd.json` (copy at `reference_workflow.json`). Subgraph-heavy production workflow with optional Refiner + FaceDetailer + ColorCorrect + FilmGrain post-processing.

37 nodes, 30 active. Six subgraphs wrap sampler logic — proxyWidgets up to 16 each.

## When to use
- User explicitly requests SDXL aesthetic (lustify, epicrealism, juggernaut, illustrious)
- Anime/illustrious illustriousRealism style
- When existing SDXL LoRAs are needed (skin_imperfection, RealSkin, add-detail, MJ52)
- Compatibility with Pony / SDXL ecosystem prompts (`score_8_up`, `score_1`, etc.)

## Pipeline stages

```
[CheckpointLoaderSimple — SDXL .safetensors (MODEL + CLIP + VAE)]
        │
        ▼
[Power Lora Loader (rgthree) — sinasdxlmy_first_lora_v1 + style boosters]
        │
        ▼
[CLIPTextEncode positive + negative]    [SDXLEmptyLatentSizePicker+ 896×1152]
        │                                              │
        ▼                                              ▼
[KSampler base — euler_ancestral / simple / 10 steps / cfg 1.5 / denoise 1.0]
        │
        ▼
[VAEDecode → IMAGE]
        │
        ▼
[FaceDetailer (Ultralytics + SAM)]
        │
        ▼
[Optional refine pass — euler_ancestral / simple / 6 steps / cfg 1.5 / denoise 0.2]
        │
        ▼
[ColorCorrect → FilmGrain → SaveImage]
```

## Required models

### Checkpoints (pick one based on user request)

| Checkpoint | Aesthetic | Best for |
|---|---|---|
| `lustifySDXLNSFW_apexV8.safetensors` | NSFW realism, "lustify" | NSFW production, default if unspecified |
| `epicrealismXL_pureFix.safetensors` | Epic realism, broad SFW/NSFW | "epicrealism" requests |
| `juggernautXL_ragnarokBy.safetensors` | Photorealistic, broad | "juggernaut" requests |
| `illustriousRealismBy_v10VAE.safetensors` | Anime/illustrious + realism | "illustrious" requests, baked VAE |
| `intorealismUltra_v10.safetensors` | Soft realism with ultra detail | alternative production |
| `mopMixtureOfPerverts_v71DMD.safetensors` | DMD-distilled NSFW | speed alternative |
| `pikonRealism_v2.safetensors` | Korean / pikon-style realism | pikon requests |
| `gonzalomoXLFluxPony_v30FluxDAIO.safetensors` | Pony/SDXL hybrid | when score_X tags needed |

If user is unspecific: use `lustifySDXLNSFW_apexV8.safetensors`.

## Sina LoRAs (pick highest epoch available)

Sina SDXL LoRAs are FLAT in `/loras/`:
- `sdxlsina_hohenheim_women_save-2999.safetensors` ← **highest epoch, default**
- `sdxlsina_hohenheim_women_save-2499.safetensors`
- `sdxlsina_hohenheim_women_save-1999.safetensors`
- `sdxlsina_hohenheim_women_save-999.safetensors`
- `sdxlsina_hohenheim_women_save-499.safetensors`

Alternative Sina LoRA used in donor:
- `sinasdxlmy_first_lora_v1_000002500.safetensors` (variant) — has 4 numeric variants `_1.safetensors`, `_2.safetensors`, `_4.safetensors`, ` (1).safetensors`

**Trigger word for SDXL: `sinahohenheim women`** (the SDXL Sina LoRAs were trained with this two-word trigger).

## Standard LoRA stack (Power Lora Loader)

| LoRA | Strength | Purpose |
|---|---|---|
| Sina SDXL LoRA | 1.0 | character |
| `skin_imperfection_sdxl.safetensors` | 0.5 | skin pores, blemishes |
| `more_details_sdxl.safetensors` | 0.4 | detail enhancement |
| `sdxloraleaked_nudes_style_v1_fixed.safetensors` | 0.7 | amateur leaked-style aesthetic |

For SFW/portrait variant:
- Replace `sdxloraleaked_nudes_style_v1_fixed` with `add-detail-xl` @ 0.4
- Optional `RealSkin_xxXL_v1` @ 1.5 for skin focus
- Optional `Dramatic Lighting Slider` @ 0.75 for cinematic lighting
- Optional `MJ52` @ 0.3 + `MJ52_v2.0` @ 0.15 for Midjourney-like aesthetic

## Default parameters

| Param | Value | Notes |
|---|---|---|
| Resolution | 896×1152 (portrait) | SDXLEmptyLatentSizePicker+ — 0.78 ratio |
| Sampler base | `euler_ancestral` | also `dpmpp_2m_sde` for higher quality |
| Scheduler base | `simple` | also `karras` / `beta` |
| Steps base | 10 | bump to 25–30 if non-DMD checkpoint |
| CFG base | 1.5 | low because LoRA stack handles guidance; bump to 5–7 for non-distilled |
| Denoise base | 1.0 | full diffusion |
| Sampler refine | `euler_ancestral` | second-pass touch-up |
| Steps refine | 6 | minimal |
| CFG refine | 1.5 | |
| Denoise refine | 0.2 | img2img top-up |

**Note:** If using a non-DMD checkpoint (`lustifySDXLNSFW_apexV8` is non-DMD), bump steps to 25–30 and CFG to 5–7. The donor's CFG=1.5 / 10-step config is for DMD-distilled variants.

Resolution presets (SDXLEmptyLatentSizePicker+ options):
- Portrait: `896×1152 (0.78)`, `832×1216 (0.68)`, `768×1344 (0.57)`
- Landscape: `1152×896`, `1216×832`, `1344×768`
- Square: `1024×1024`

## Variable inputs (per run)

| What | Where | Notes |
|---|---|---|
| Checkpoint | CheckpointLoaderSimple `ckpt_name` | swap based on user request |
| Positive prompt | CLIPTextEncode positive | include `sinahohenheim women` + scene |
| Negative prompt | CLIPTextEncode negative | standard SDXL negative |
| LoRA stack | Power Lora Loader 93 | toggle on/off via `on` flag |
| Resolution | SDXLEmptyLatentSizePicker+ 13 | preset string |
| Seed | (subgraph proxy) | randomize |

## Code skeleton

```python
import json, copy, urllib.request, uuid, time, datetime, random

REF = "/workspace/.claude/skills/sina_image_sdxl/reference_workflow.json"
HOST = "http://localhost:8188"

CKPT_MAP = {
    "lustify":      "lustifySDXLNSFW_apexV8.safetensors",
    "epicrealism":  "epicrealismXL_pureFix.safetensors",
    "juggernaut":   "juggernautXL_ragnarokBy.safetensors",
    "illustrious":  "illustriousRealismBy_v10VAE.safetensors",
    "intorealism":  "intorealismUltra_v10.safetensors",
    "pikon":        "pikonRealism_v2.safetensors",
    "pony":         "gonzalomoXLFluxPony_v30FluxDAIO.safetensors",
    "mop":          "mopMixtureOfPerverts_v71DMD.safetensors",
}

def submit(prompt: str, *, ckpt_keyword: str = "lustify", seed: int = None,
           res: str = "896x1152 (0.78)") -> str:
    with open(REF) as f:
        wf = json.load(f)  # assumes API format — see workflow_factory for graph→API
    if seed is None:
        seed = random.randint(0, 2**31)
    ckpt_file = CKPT_MAP.get(ckpt_keyword.lower(), CKPT_MAP["lustify"])

    for nid, node in wf.items():
        ct = node.get("class_type")
        inp = node.get("inputs", {})
        if ct == "CheckpointLoaderSimple":
            inp["ckpt_name"] = ckpt_file
        if ct == "CLIPTextEncode" and "sinahohenheim" in inp.get("text",""):
            inp["text"] = prompt  # ensure prompt has 'sinahohenheim women'
        if ct == "KSampler" or ct == "KSamplerAdvanced":
            if "seed" in inp: inp["seed"] = seed
            if "noise_seed" in inp: inp["noise_seed"] = seed
        if ct == "SDXLEmptyLatentSizePicker+":
            inp["resolution"] = res
        if ct == "SaveImage":
            inp["filename_prefix"] = f"{datetime.date.today():%Y%m%d}_sdxl-{ckpt_keyword}"

    payload = {"prompt": wf, "client_id": str(uuid.uuid4())}
    req = urllib.request.Request(f"{HOST}/prompt",
                                 data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)["prompt_id"]
```

## Alternative donor workflows

- `SDXL Realism+ Rifiner gönnen.json` — SDXL with full FaceDetailer chain + 2-pass sampling, uses `intorealismUltra_v80` and broader LoRA stack
- `Image_SDXL_lustify_with_zimage_face_detailers.json` — SDXL + Z-Image cross-detailer
- `IMAGE_BEST_v7_CleanSurgeryChain_LustifyGenitals.json` — surgery-focused variant
- `Pikon Realism best nude scene sdxl1afad5f3-769f-446c-981c-7bcc006b9f96.json` — pikon-specific
- `aiorbust-sdxl-nsfw-lustify.json` — alt lustify variant
- `Perfect NUDES SDXL aswell0d924db8-f2c4-49c9-8e1e-90dd5cde7e7b.json` — alternative NSFW
- `SDXL mage gonzaLomo_DMD_v31_clean.json` — gonzaLomo DMD variant
- `SDXL mopMixWorkflows_BigASP25.json` — BigASP-tagged variant

## Common Pitfalls

**MODEL AVAILABILITY (verified 2026-05-02):**
- ⚠️ `sinasdxlmy_first_lora_v1_000002500.safetensors` and all 4 variants (` (1)`, `_1`, `_2`, `_4`) — only `.metadata.json` exists, **`.safetensors` files MISSING**. Default to `sdxlsina_hohenheim_women_save-2999.safetensors` instead (verified available).
- ✅ All 9 SDXL checkpoints (`lustifySDXLNSFW_apexV8`, `epicrealismXL_pureFix`, `juggernautXL_ragnarokBy`, `illustriousRealismBy_v10VAE`, `intorealismUltra_v10`, etc.) verified present.
- ✅ `skin_imperfection_sdxl`, `more_details_sdxl`, `add-detail-xl`, `RealSkin_xxXL_v1` all verified present.

_(other pitfalls — populate with experience: trigger word case sensitivity (`sinahohenheim women` vs `sinahohenheim_women`), DMD vs non-DMD CFG mismatch causing washed-out outputs, SDXLEmptyLatentSizePicker+ resolution string format strict ("896x1152 (0.78)" with space), illustriousRealism baked VAE conflicting with external VAE if loaded, score_X Pony tags only working with gonzalomoXLFluxPony)_
