---
name: sina_image_zimage_base
description: Generate Sina images using Z-Image Base with sinaneu LoRA. Best quality production pipeline. Use for high-fidelity Sina images, FaceLocked pipelines, production-grade renders. Triggers - "Z-Image", "zimage", "Sina image", "sinaneu", "best quality image", "production image".
tools: Bash, Read, Write
---

# sina_image_zimage_base

Best-quality Sina image production pipeline. Reference: `BEST IMAGE WFCLSNP_GOATR_Pinterest_SilentSnow_v2_1_FaceLocked Zimage+Zturbo+3upscalerefiner.json` (copy at `reference_workflow.json`). Multi-stage hybrid: Z-Image Base/Turbo generate → SDXL refinement → SeedVR2 upscale → FaceDetailer chain → character-locked final.

89 nodes, 78 active. Heavy use of subgraphs and FaceDetailer for face-locked character continuity.

## When to use
- Production hero images
- Pinterest-locked aesthetic ("SilentSnow", "SilverSnow" variants)
- Anywhere face fidelity matters more than render speed
- Final outputs that go into i2v video pipelines

## Pipeline stages

```
[CLIPLoader qwen_3_4b lumina2]   [VAELoader ae]
        │                                │
        ▼                                ▼
[CLIPTextEncode positive (1326/67)]   [CLIPTextEncode negative (71/1327)]
        │
        ▼
[UNETLoader Z-Image variant] → [CR LoRA Stack: sinaneu_000002700 + extras]
        │
        ▼
[KSampler base — dpmpp_2m / ddim_uniform / 25 steps / cfg 5 / denoise 1.0]
        │ (LATENT)
        ▼
[VAEDecode → IMAGE]
        │
        ▼
[FaceDetailer chain — Ultralytics + SAM, character-locked]
        │
        ▼
[3-stage upscale refiner — SeedVR2 (DiT + VAE) or ImageScaleToMaxDimension]
        │
        ▼
[KSampler refine — euler / beta / 6 steps / cfg 1 / denoise 0.35]
        │
        ▼
[Multiple SaveImage outputs: Base, Heavy Refinement, Final Upscaled, Character-Locked Final]
```

## Required models

| Slot | File | Notes |
|---|---|---|
| Z-Image UNet (base) | `z_image_bf16.safetensors` or `zEpicrealism_turboV1Fp8.safetensors` | in `/models/diffusion_models/` |
| CLIP | `qwen_3_4b.safetensors` (type=`lumina2`) | in `/models/text_encoders/` |
| VAE | `ae.safetensors` | universal Flux/Z-Image VAE in `/models/vae/` |
| Refiner UNet (optional) | `ultrarealFineTune_v4.safetensors` (Flux-based) | for SDXL refinement stage |
| SDXL refiner ckpt (optional) | `lustifySDXLNSFW_ggwpV7.safetensors` or `lustifySDXLNSFW_apexV8.safetensors` | for SDXL refinement stage |
| Upscale model | SeedVR2 DiT + VAE | in `/models/SEEDVR2/` |
| FaceDetailer | UltralyticsDetectorProvider model + SAM | for face-lock |

## Active LoRAs (Z-Image Base stage)

| LoRA | Strength | Purpose |
|---|---|---|
| `sinaneu_000002700.safetensors` | 1.0 | **Sina character (PRIMARY)** |
| `gta6_amateur_photography_zimagebase_v2.safetensors` | varies | amateur photo aesthetic |
| `nicegirls_zimagebase.safetensors` | varies | body/style polish |
| `lenovo_zimagebase.safetensors` | varies | additional style anchor |

For final FaceLock pass: separate `Lora Loader Stack (rgthree)` with `sinaneu_000002700` + `RealisticSnapshot-Zimage-Turbov5`.

## Default parameters

| Param | Value | Source |
|---|---|---|
| Resolution | typically 1024×1024 or 1080×1920 portrait | EmptySD3LatentImage / SDXLEmptyLatentSizePicker+ |
| Base sampler | `dpmpp_2m` | KSampler 69 |
| Base scheduler | `ddim_uniform` | KSampler 69 |
| Base steps | 25 | KSampler 69 |
| Base CFG | 5 | KSampler 69 |
| Base denoise | 1.0 | KSampler 69 (full diffusion) |
| Refine sampler | `euler` | KSampler 92 |
| Refine scheduler | `beta` | KSampler 92 |
| Refine steps | 6 | KSampler 92 |
| Refine CFG | 1 | KSampler 92 |
| Refine denoise | 0.35 | KSampler 92 (img2img top-up) |

Trigger word: `sinahohenheim` (always in positive prompt)

## Variable inputs (per run)

| What | Where | Notes |
|---|---|---|
| Positive prompt | CLIPTextEncode 1326 (face-lock) and/or 67 (scene) | Always include `sinahohenheim` |
| Negative prompt | CLIPTextEncode 71 / 1327 | Standard anti-artifact list, keep as-is |
| Resolution | EmptySD3LatentImage / SDXLEmptyLatentSizePicker+ | 1024×1024 default; 1080×1920 for portrait |
| Seed | KSampler 69 (`seed`) and 92 (`seed`) | randomize for variety |
| LoRA strengths | CR LoRA Stack 100 / Lora Loader Stack 1322/1323 | Tune sinaneu 0.8–1.0 typical |
| Save filename prefix | SaveImage nodes (1313, 1314, 1318, 1329) | Use YYYYMMDD_descriptive-slug |

## Code skeleton

```python
import json, copy, urllib.request, uuid, time, datetime

REF = "/workspace/.claude/skills/sina_image_zimage_base/reference_workflow.json"
HOST = "http://localhost:8188"

def load_reference():
    with open(REF) as f:
        return json.load(f)

def submit_api(api_wf: dict, prompt: str, seed: int = None, prefix: str = None) -> str:
    """Assumes api_wf is in API format (use UI Save (API Format) once and store as reference_api.json)."""
    wf = copy.deepcopy(api_wf)
    if seed is None:
        import random; seed = random.randint(0, 2**31)
    if prefix is None:
        prefix = f"{datetime.date.today():%Y%m%d}_sina-zimage-base"

    for nid, node in wf.items():
        ct = node.get("class_type")
        inp = node.get("inputs", {})
        # positive prompt: heuristic — first CLIPTextEncode that contains 'sinahohenheim' or has the longest text
        if ct == "CLIPTextEncode" and "sinahohenheim" in inp.get("text",""):
            inp["text"] = prompt
        if ct == "KSampler":
            inp["seed"] = seed
        if ct == "SaveImage":
            inp["filename_prefix"] = prefix

    payload = {"prompt": wf, "client_id": str(uuid.uuid4())}
    req = urllib.request.Request(f"{HOST}/prompt",
                                 data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)["prompt_id"]

def poll(prompt_id: str, timeout=600, interval=2):
    deadline = time.time() + timeout
    while time.time() < deadline:
        with urllib.request.urlopen(f"{HOST}/history/{prompt_id}") as r:
            hist = json.load(r)
        if prompt_id in hist:
            return hist[prompt_id]
        time.sleep(interval)
    raise TimeoutError(prompt_id)
```

## Alternative donor workflows (Z-Image Base family)

For variants or fallbacks:
- `IMAGE_BEST_IMAGE_WF_CLSNP_GOATR_Pinterest_SilentSnow_v5_1080x1920.json` — 1080×1920 portrait variant
- `IMAGE_BEST_v7_CleanSurgeryChain_LustifyGenitals.json` — clean surgery chain variant
- `Image BESTSina_Undressing_Workflow_v5_MaxRealism (2).json` — undressing scene variant
- `GOAT ZIMAGE+Tzurboupscale+SNOWYFACEDETAILS.json` — snowy face details variant
- `Image GOAATT Zturbo Full 1 gute_NSFW_Z_IMAGE_with_Detailers.json` — full Z-Image with detailers
- `CLSNP_GOATR_Pinterest_SilentSnow_v2_1_FaceLocked.json` — older v2 base

When user requests a variant, use `workflow_factory` skill to compare donors and pick the closest match.

## Common Pitfalls
_(empty — populate with experience. Likely candidates: SeedVR2 OOM on 23GB L4 (drop to single upscale stage), FaceDetailer with wrong bbox confidence dropping faces, Z-Image vs Flux UNet confusion since both VAE is `ae.safetensors`, Pinterest/SilentSnow scene anchors getting overridden by user prompt)_
