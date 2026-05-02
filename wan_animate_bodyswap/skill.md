---
name: wan_animate_bodyswap
description: Full body face/character swap using WAN Animate. Use for replacing existing video subject with Sina or any swap target. Supports batch mode. Triggers - "body swap", "WAN animate", "face swap video", "character swap", "icekiub".
tools: Bash, Read, Write
---

# wan_animate_bodyswap

WAN Animate full-body / face swap pipeline. Reference: `CLSNP Sven BATCH ICY WAN ANIMATE - Full Body Swap -prer- Icekiub V4.json` (copy at `reference_workflow.json`). Replaces the subject in an existing video with a target character, preserving motion + camera + background.

105 nodes, 88 active. Heavy use of `GetNode`/`SetNode` for cross-graph variable routing (12+12). Pre-render Flux Klein step generates a target reference frame which then drives the WAN Animate sampling.

## When to use
- User wants Sina (or any character) swapped into an existing video
- Source video has different person; outfit/scene should be preserved, person replaced
- "Icekiub V4" or "Icekiub variants" mentioned
- Batch mode: process multiple source videos with same target character
- Pre-render mode: generate a still-frame reference of the target first, then drive video swap

## Pipeline stages

```
[VHS_LoadVideo source.mp4] ─┬───────────────┐
                            │               │
                            ▼               ▼
                    [DWPreprocessor]   [Frame Select frame 0]
                    (pose extraction)        │
                            │                ▼
                            │       [SAM3Segmentation: extract person mask]
                            │                │
                            │                ▼
                            │       [easy imageCropFromMask: cropped subject]
                            │                │
                            │                ▼
                            │       [BlockifyMask + DrawMaskOnImage]
                            │                │
                            └────────────────┤
                                             ▼
                       ┌────────────────────────────────────────┐
                       │  PRE-RENDER STAGE (Flux Klein 9B)      │
                       │                                        │
                       │  [LoadImage Sina ref] → [VAEEncode]    │
                       │  → [ReferenceLatent]                   │
                       │  + [LoraLoaderModelOnly chain:         │
                       │     sinafluxneu_000000800,             │
                       │     FLUXklein_slider_anatomy,          │
                       │     lenovo_flux_klein9b,               │
                       │     nicegirls_flux_klein9b]            │
                       │  → [KSampler res_2s/beta57/6 steps]    │
                       │  → reference Sina frame                │
                       └─────────────────┬──────────────────────┘
                                         │
                                         ▼
                            [CLIPVisionEncode] ← reference frame
                                         │
                                         ▼
                       ┌─────────────────────────────────────────┐
                       │  WAN ANIMATE STAGE                      │
                       │                                         │
                       │  [UNETLoader Wan2_2-Animate-14B_fp8]    │
                       │  → [LoraLoaderModelOnly:                │
                       │     WanAnimate_relight_lora_fp16,       │
                       │     lightx2v_I2V_14B_480p_distill]      │
                       │  → [ModelSamplingSD3]                   │
                       │  → [Sampler subgraph]                   │
                       │  → IMAGE batch (animated)               │
                       └─────────────────┬───────────────────────┘
                                         │
                                         ▼
                                  [RIFE VFI 2×]
                                         │
                                         ▼
                                  [VHS_VideoCombine]
                                         │
                                         ▼
                            /output/AnimateDiff/[swap].mp4
```

5 separate `VHS_VideoCombine` nodes save intermediate stages (pose preview, mask preview, pre-render, animated, final) at varying frame rates (8/15/32 fps).

## Required models

| Slot | File | Notes |
|---|---|---|
| WAN Animate UNet | `Wan2_2-Animate-14B_fp8_e4m3fn_scaled_KJ.safetensors` | in `/models/diffusion_models/` |
| WAN CLIP | `umt5_xxl_fp8_e4m3fn_scaled.safetensors` (type=`wan`) | in `/models/text_encoders/` |
| WAN VAE | `wan_2.1_vae.safetensors` | for Animate stage |
| Flux Klein UNet | `flux-2-klein-9b.safetensors` | pre-render stage |
| Flux Klein CLIP | `qwen_3_8b_fp8mixed.safetensors` (type=`flux2`) | pre-render |
| Flux Klein VAE | `flux2-vae.safetensors` | pre-render |
| CLIPVisionLoader | model | for image conditioning |
| DWPreprocessor | model | pose extraction |
| SAM3 | model | person segmentation |

## Active LoRAs

### WAN Animate stage
| LoRA | Strength | Purpose |
|---|---|---|
| `WanAnimate_relight_lora_fp16.safetensors` | 1.0 | relighting (essential — without it, characters look pasted-on) |
| `lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors` | 1.0 | 4-step distillation (480p variant) |

### Flux Klein pre-render stage
| LoRA | Strength | Purpose |
|---|---|---|
| `sinafluxneu_000000800.safetensors` | 1.0 | **Sina character (PRIMARY)** |
| `FLUXklein_slider_anatomy.safetensors` | varies | anatomy enhancement |
| `lenovo_flux_klein9b.safetensors` | varies | body aesthetic |
| `nicegirls_flux_klein9b.safetensors` | varies | face polish |

To swap a different character: replace `sinafluxneu_000000800` with target character LoRA + adjust LoadImage source reference.

## Default parameters

| Param | Value | Notes |
|---|---|---|
| Source FPS | 32 (force_rate) | VHS_LoadVideo `force_rate` |
| Output FPS | 32 (final), 15/8 intermediate | per VHS_VideoCombine |
| Pre-render sampler | `res_2s` | KSampler 571 |
| Pre-render scheduler | `beta57` | KSampler 571 |
| Pre-render steps | 6 | |
| Pre-render CFG | 1.0 | Flux Klein default |
| Pre-render denoise | 1.0 | full |
| WAN Animate sampler params | inside subgraph 282/285 | proxy widgets |

## 5-variation per-block prompt pattern

The donor uses 2 CLIPTextEncode nodes (one positive, one negative) but the prompt structure encourages "multi-block" descriptions:

```
Remove and Replace the character in image 1, preserve the background

sinahohenheim,
[block 1: physical traits — hair color, eye color, skin tone, build]
[block 2: outfit — keep matching the original outfit IF preserving]
[block 3: face details — facial features, expressions]
[block 4: pose anchor — match source video subject's pose framing]
[block 5: aesthetic — lighting, mood, photo style]
```

The 5 blocks let you tune each aspect independently. Default donor uses:
- "she has long blackbrown hair with white blonde streaks"
- "keep the outfit the same"
- (more blocks per variation)

## Variable inputs (per run)

| What | Where | Notes |
|---|---|---|
| Source video | VHS_LoadVideo 579 `video` | filename relative to `/input/videos/` |
| Sina reference image | LoadImage 316 | first-frame reference for Flux Klein pre-render |
| Positive prompt | CLIPTextEncode 550 | 5-block character description |
| Negative prompt | CLIPTextEncode 549 | typically empty for Flux Klein |
| Sina LoRA | LoraLoaderModelOnly 617 | swap to different character LoRA |
| Output prefix | VHS_VideoCombine final | `AnimateDiff/[slug]` |

## Batch mode

For batch processing multiple source videos with same Sina target:
1. Replace `VHS_LoadVideo` with `SvenLoadVideoFolder` (already used in graph at node 622)
2. Set `folder_path` to `/workspace/runpod-slim/ComfyUI/input/videos/[batch_dir]/`
3. Loop will iterate through all videos in folder
4. Each output saves with auto-incremented filename

## Code skeleton

```python
import json, copy, urllib.request, uuid, time, datetime

REF = "/workspace/.claude/skills/wan_animate_bodyswap/reference_workflow.json"
HOST = "http://localhost:8188"

def submit(source_video: str, sina_ref_image: str, *, prompt: str = None,
           seed: int = None, batch_folder: str = None) -> str:
    with open(REF) as f:
        wf = json.load(f)  # API format expected

    if seed is None:
        import random; seed = random.randint(0, 2**31)

    DEFAULT_PROMPT = (
        "Remove and Replace the character in image 1, preserve the background\n\n"
        "sinahohenheim, she has long blackbrown hair with white blonde streaks,"
        " keep the outfit the same as the source, match the original pose and framing,"
        " natural lighting, amateur photo aesthetic"
    )
    prompt = prompt or DEFAULT_PROMPT

    for nid, node in wf.items():
        ct = node.get("class_type")
        inp = node.get("inputs", {})
        if ct == "VHS_LoadVideo":
            inp["video"] = source_video
        if ct == "LoadImage":
            inp["image"] = sina_ref_image
        if ct == "CLIPTextEncode" and "Replace" in inp.get("text",""):
            inp["text"] = prompt
        if ct == "KSampler":
            inp["seed"] = seed
        if ct == "SvenLoadVideoFolder" and batch_folder:
            inp["folder_path"] = batch_folder
        if ct == "VHS_VideoCombine":
            inp["filename_prefix"] = f"AnimateDiff/{datetime.date.today():%Y%m%d}_sina-swap"

    payload = {"prompt": wf, "client_id": str(uuid.uuid4())}
    req = urllib.request.Request(f"{HOST}/prompt",
                                 data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)["prompt_id"]
```

## Alternative donor workflows

- `CLSNP Sven ICY WAN ANIMATE - Full Body Swap -prer- Icekiub V4.json` — single (non-batch) version
- `ClaudeCode WAN ANIMATE - Full Body Swap -prer- Icekiub V4.json` — ClaudeCode-prefixed variant
- `ClaudeCode free WANT2VLora Faceswap - Icekiub v1 ( load video folder ohne tt link eingeben).json` — folder-load t2v faceswap variant
- `ClaudeCopde WANT2VLora Faceswap - Icekiub v1 (3)( mit TTlink adden und dann komt der Faceswap), der node muss aber noch erstellt werden mit link eingeben.json` — TT-link variant (typo in filename)
- `NSFW SURGERY SUBS - ICEKIUB v1.json` — surgery+subs variant

For face-only swap (not full body): use `Flux2 Klein 9b Face Swap.json` or `flux2-klein-editing+face swap.json` (Flux Klein face swap, no WAN Animate stage).

## Common Pitfalls
_(empty — populate with experience. Likely candidates: source video FPS mismatch (force_rate must match expected output); SAM3 segmentation failing on multi-person videos (works best with single-subject input); pre-render Flux Klein face NOT carrying through to WAN Animate if CLIPVision conditioning weight too low; WanAnimate_relight LoRA strength < 1.0 produces obvious cutout look; lightx2v 480p distill incompatible with 720p WAN inference (use 480p source resolution); GetNode/SetNode wiring breaks if any node is bypassed in the chain — verify node IDs match across the graph)_
