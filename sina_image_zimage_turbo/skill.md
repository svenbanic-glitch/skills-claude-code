---
name: sina_image_zimage_turbo
description: Fast Sina image generation using Z-Image Turbo (~2s/image). Use for drafts, batch tests, prompt iteration, quick previews. Triggers - "fast image", "draft", "z-turbo", "quick test", "schnell test".
tools: Bash, Read, Write
---

# sina_image_zimage_turbo

Fast Sina draft pipeline. Reference: `Image  Zturbo direktCLSNP_ZImageTurbo_Direct_v6.json` (copy at `reference_workflow.json`). Single-pass Z-Image Turbo at 8 steps — ~2s per 1024² image on L4.

72 nodes, 64 active. Optional FaceDetailer + SeedVR2 chain bypassable for max speed.

## When to use
- Prompt iteration / experimentation (fast feedback loop)
- Batch tests of LoRA combinations
- Pinterest-style preview drafts
- Anywhere quality < 90% acceptable in exchange for ~10–20× speedup vs `sina_image_zimage_base`

## Pipeline stages

```
[CLIPLoader qwen_3_4b lumina2]   [VAELoader ae]   [UNETLoader z_image_turbo_bf16]
        │                                │                          │
        ▼                                                            ▼
[CLIPTextEncode positive (67 / 1326)]                  [Power Lora Loader (rgthree)]
[CLIPTextEncode negative (71 / 1327)]                          │
        │                                                       ▼
        ▼                                              [LoRA-injected MODEL]
[EmptySD3LatentImage 1024×1024]
        │
        ▼
[KSampler (1344) — euler / beta57 / 8 steps / cfg 1.4 / denoise 1.0]
        │
        ▼
[VAEDecode → IMAGE]
        │
        ▼
[Optional: FaceDetailer chain → SeedVR2 upscale]
        │
        ▼
[SaveImage `Turbo Direct/Raw` or `Silent Snow RSV5 ...`]
```

## Required models

| Slot | File | Notes |
|---|---|---|
| UNet | `z_image_turbo_bf16.safetensors` | in `/models/diffusion_models/` |
| CLIP | `qwen_3_4b.safetensors` (type=`lumina2`) | shared with Z-Image Base |
| VAE | `ae.safetensors` | shared |

GGUF alternative: `z_image_turbo-Q4_K_M.gguf` for tighter VRAM (use `UnetLoaderGGUF` instead of `UNETLoader`).

## Active LoRA stack (Power Lora Loader 1343)

| LoRA | Strength | Purpose |
|---|---|---|
| `sinaneu_000002700.safetensors` | 1.0 | **Sina character (PRIMARY)** |
| `Mystic-XXX-ZIT-V5.safetensors` | 0.5 | NSFW polish (Z-Image Turbo trained) |
| `RealisticSnapshot-Zimage-Turbov5.safetensors` | 0.6 | iPhone-snapshot aesthetic |
| `zimageb3tternud3s_v3.safetensors` | 0.6 | nudity quality lift |
| `zturbodildo.safetensors` | 0.9 | scene-specific (toggle off if not needed) |
| `ZIT_Breast_V2.1_000001250.safetensors` | 0.6 | anatomy detail |

For pure portrait without NSFW: keep only `sinaneu` @ 1.0 + `RealisticSnapshot-Zimage-Turbov5` @ 0.6.

Trigger word: `sinahohenheim`

## Default parameters

| Param | Value | Source |
|---|---|---|
| Resolution | 1024 × 1024 | EmptySD3LatentImage (override per call) |
| Sampler | `euler` | KSampler 1344 |
| Scheduler | `beta57` | KSampler 1344 |
| Steps | 8 | KSampler 1344 |
| CFG | 1.4 | KSampler 1344 (low — turbo distilled) |
| Denoise | 1.0 | KSampler 1344 |
| Seed | randomize | KSampler 1344 |

**Speed:** ~2s/image on NVIDIA L4 at 1024² with 8 steps and 6 LoRAs loaded.

## Variable inputs (per run)

| What | Where | Notes |
|---|---|---|
| Positive prompt | CLIPTextEncode 67 (scene) or 1326 (face-lock) | always include `sinahohenheim` |
| Resolution | EmptySD3LatentImage | 1024² typical, 832×1216 portrait, 1216×832 landscape |
| Seed | KSampler 1344 | randomize for variety |
| LoRA strengths | Power Lora Loader 1343 | adjust per scene |
| Save filename | SaveImage 1346 (Turbo Direct/Raw) | YYYYMMDD_descriptive-slug |

## Code skeleton

```python
import json, copy, urllib.request, uuid, time, datetime, random

REF = "/workspace/.claude/skills/sina_image_zimage_turbo/reference_workflow.json"
HOST = "http://localhost:8188"

def submit_batch(prompts: list[str], base_seed: int = None) -> list[str]:
    """Submit N prompts as N separate generations. Returns list of prompt_ids."""
    with open(REF) as f:
        template = json.load(f)
    # Convert to API format first (use UI Save (API Format) to produce reference_api.json once).
    # For now this assumes API format input.
    ids = []
    for i, p in enumerate(prompts):
        seed = (base_seed or random.randint(0, 2**31)) + i
        wf = copy.deepcopy(template)
        for nid, node in wf.items():
            ct = node.get("class_type")
            inp = node.get("inputs", {})
            if ct == "CLIPTextEncode" and "sinahohenheim" in inp.get("text",""):
                inp["text"] = p
            if ct == "KSampler":
                inp["seed"] = seed
            if ct == "SaveImage":
                inp["filename_prefix"] = f"{datetime.date.today():%Y%m%d}_zturbo_{i:03d}"

        payload = {"prompt": wf, "client_id": str(uuid.uuid4())}
        req = urllib.request.Request(f"{HOST}/prompt",
                                     data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req) as r:
            ids.append(json.load(r)["prompt_id"])
    return ids
```

## Alternative donor workflows

- `Image SFW Z IMAGE .json` — SFW-only Z-Image Turbo
- `Image GOAATT Zturbo Full 1 gute_NSFW_Z_IMAGE_with_Detailers.json` — Z-Image Turbo with detailer chain
- `ClaudeCode Zimage+ZturboUpscale+Pinterest Download mit Grok Prompting.json` — Z-Turbo + Pinterest scrape + Grok prompts (full automation pipeline)
- `ClaudeCode ZiT img2img LoRAtech.json` — img2img Z-Image Turbo variant

## Common Pitfalls
_(empty — populate with experience. Likely candidates: CFG > 2 producing artifacts on turbo distilled, sampler other than `euler`/`euler_ancestral` failing, `beta57` scheduler not in older Comfy versions (fallback `beta`), turbo LoRAs incompatible with Base-trained LoRAs (don't mix sinaneu Z-Image Base LoRA with z_image_turbo UNet without checking))_
