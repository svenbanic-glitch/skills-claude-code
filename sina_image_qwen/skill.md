---
name: sina_image_qwen
description: Generate Sina images using Qwen Image. Use when Qwen-specific aesthetics needed. Triggers - "qwen image", "qwen", "qwen-mysticxxx".
tools: Bash, Read, Write
---

# sina_image_qwen

Qwen Image Sina pipeline. Reference: `QWEN Nsfw + Klein faceswap - icekiub v1.json` (copy at `reference_workflow.json`). Despite "Klein faceswap" in filename, this is a Qwen-only generation workflow with Lightning 8-step distillation + multi-LoRA Qwen stack.

35 nodes, 18 active. Uses `ClownsharKSampler_Beta` (rationalized custom sampler) with `ModelSamplingAuraFlow` patch.

## When to use
- User explicitly requests Qwen aesthetic
- When Qwen-trained Sina LoRA is the best match (`sina qwen_*`)
- "MysticXXX" / "snofs" Qwen-specific styles
- Qwen-Image Lightning distillation for fast Qwen renders

## Pipeline stages

```
[CLIPLoader qwen_2.5_vl_7b_fp8 qwen_image]   [VAELoader qwen_image_vae]
                          │                              │
                          ▼                              ▼
[CLIPTextEncode positive]                     [UNETLoader qwen_image_fp8_hq]
[CLIPTextEncode negative]                              │
        │                                              ▼
        │                              [LoraLoaderModelOnly chain — 4 LoRAs]
        │                                              │
        ▼                                              ▼
[ModelSamplingAuraFlow]              ←───────────────────
        │
        ▼
[EmptySD3LatentImage]
        │
        ▼
[ClownsharKSampler_Beta — exponential/res_2s / ddim_uniform / 10 steps / cfg 1 / Lightning 8-step]
        │
        ▼
[VAEDecode → IMAGE]
        │
        ▼
[SaveImage]
```

`ClownOptions_DetailBoost_Beta` patches detail enhancement onto the sampler.
`SvenSmartPromptList` provides multi-line prompt batch input.

## Required models

| Slot | File | Notes |
|---|---|---|
| UNet | `qwen_image_fp8_hq.safetensors` | in `/models/diffusion_models/` |
| CLIP | `qwen_2.5_vl_7b_fp8_scaled.safetensors` (type=`qwen_image`) | in `/models/text_encoders/` |
| VAE | `qwen_image_vae.safetensors` | Qwen-specific VAE |

GGUF alternatives: `qwen-image-2512-Q4_K_M.gguf` (use `UnetLoaderGGUF`).

## Active LoRA stack

| LoRA | Strength | Purpose |
|---|---|---|
| `Qwen-Image-Lightning-8steps-V2.0-bf16.safetensors` | 1.0 | **8-step distillation (REQUIRED for Lightning sampling)** |
| `sina qwen.safetensors` (or `_000003400` highest epoch) | 1.0 | **Sina character (PRIMARY)** |
| `Qwen-MysticXXX-v1.safetensors` | 0.7–1.0 | NSFW/aesthetic anchor |
| `Qwen_Snofs_1_3.safetensors` | 0.5–0.8 | snofs style |

Sina Qwen LoRAs (highest first):
- `sina qwen_000003400.safetensors`
- `sina qwen_000001400.safetensors`
- `sina qwen_000000400.safetensors`
- `sina qwen.safetensors` (final / base name)

Trigger word: `sinahohenheim`

## Default parameters

| Param | Value | Notes |
|---|---|---|
| Resolution | typically 1024² or 1328×1024 | EmptySD3LatentImage |
| Sampler | `res_2s` (rationalized exponential) | ClownsharKSampler_Beta |
| Scheduler | `ddim_uniform` | ClownsharKSampler_Beta |
| Steps | 10 | with Lightning 8-step LoRA active |
| CFG | 1.0 | Qwen-Image Lightning expects ~1.0 |
| Sigma options | exponential | `0.75` start sigma |
| Detail boost | enabled | ClownOptions_DetailBoost_Beta patch |

## Variable inputs (per run)

| What | Where | Notes |
|---|---|---|
| Positive prompt | CLIPTextEncode 13 `text` | include `sinahohenheim` |
| Negative prompt | CLIPTextEncode 12 `text` | standard Qwen anti-artifact |
| Prompt list (batch) | SvenSmartPromptList 46 `prompt_list` | `---` separated |
| Seed | ClownsharKSampler_Beta 4 `seed` (8th value in widgets) | randomize |
| LoRA strengths | LoraLoaderModelOnly 7/8/9/10 | tune sina + style mix |

## Code skeleton

```python
import json, copy, urllib.request, uuid, time, datetime, random

REF = "/workspace/.claude/skills/sina_image_qwen/reference_workflow.json"
HOST = "http://localhost:8188"

def submit(prompt: str, *, seed: int = None, sina_lora: str = "sina qwen_000003400.safetensors") -> str:
    with open(REF) as f:
        wf = json.load(f)
    if seed is None: seed = random.randint(0, 2**31)

    for nid, node in wf.items():
        ct = node.get("class_type")
        inp = node.get("inputs", {})
        if ct == "CLIPTextEncode":
            t = inp.get("text","")
            # positive: longer text without 'low quality' negatives
            if "low quality" not in t.lower() and "blurry" not in t.lower():
                inp["text"] = prompt
        if ct == "LoraLoaderModelOnly" and "sina qwen" in inp.get("lora_name",""):
            inp["lora_name"] = sina_lora
        if ct == "ClownsharKSampler_Beta":
            # widgets_values index 7 is seed (varies — verify via /object_info)
            inp["seed"] = seed
        if ct == "SaveImage":
            inp["filename_prefix"] = f"{datetime.date.today():%Y%m%d}_qwen"

    payload = {"prompt": wf, "client_id": str(uuid.uuid4())}
    req = urllib.request.Request(f"{HOST}/prompt",
                                 data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)["prompt_id"]
```

## Alternative donor workflows

- `Sven QWEN IMAGE UNLEASHED EDIT Pics.json` — **CAUTION:** despite "QWEN" in name, this is actually a Flux Klein 9B workflow (uses `flux-2-klein-9b` UNet). Use `sina_image_fluxklein` skill instead.
- `Sven NSFW Round.json` — references qwen_image
- `SNP Nano Gen+Synthid-Bypass-v2 (2).json` — Qwen + Synthid-Bypass for content-policy evasion

If user asks for "Qwen edit" (img2img on existing image): copy `ReferenceLatent` pattern from `sina_image_fluxklein` skill — replace the UNet/CLIP/VAE with Qwen counterparts.

## Common Pitfalls
_(empty — populate with experience. Likely candidates: Lightning 8-step LoRA REQUIRED at strength 1.0 — without it, 10-step samples produce noise; ClownsharKSampler_Beta widgets_values mapping is non-obvious — always verify via /object_info; Qwen CLIP type must be `qwen_image` not `qwen` or `qwen2`; Qwen VAE NOT interchangeable with `ae.safetensors` or `flux2-vae.safetensors`; CFG > 1.5 with Lightning LoRA produces washed-out outputs)_
