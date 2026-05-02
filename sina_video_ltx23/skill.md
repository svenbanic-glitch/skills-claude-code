---
name: sina_video_ltx23
description: Generate video with LTX 2.3 two-pass pipeline. Use for LTX 2.3 image-to-video or text-to-video, audio-from-prompt scenarios, longer coherent motions than WAN. Triggers - "LTX 2.3", "LTX23", "ltx video", "audio prompt video".
tools: Bash, Read, Write
---

# sina_video_ltx23

LTX 2.3 i2v / t2v pipeline. Reference: `ClaudeCode Ltx 2.3 SFW WF.json` (copy at `reference_workflow.json`). The reference is heavily subgraph-wrapped — sampling logic (CheckpointLoader, LoRAs, two-pass sampling, latent upscale) lives inside subgraph `267` with 11 proxy widgets.

5 visible nodes (the bulk is in subgraphs). For unwrapped pipeline structure see `CLSNP_LTX23_SECTIONED_12x5s.json` (368 nodes, 4 sections × full LTX 2-pass).

## When to use
- User asks for LTX 2.3 video
- Coherent longer motions (>10s) where WAN 2.2 drifts
- Audio-derived-from-prompt scenarios
- Two-pass quality where low-res sampling + 2× latent upscale produces sharper results than WAN

## Pipeline stages (LTX 2.3 standard 2-pass)

```
[CheckpointLoaderSimple — ltx-2.3-22b-dev (or fp8)]
        │
        ▼
[LoraLoaderModelOnly — ltx-2.3-22b-distilled-lora-384 + scene LoRAs]
        │
        ▼
[LTXAVTextEncoderLoader — gemma_3_12B_it_fp8_e4m3fn]
        │
        ▼
[CLIPTextEncode positive + negative]
        │
        ▼
[LoadImage source]
        │
        ▼
[ResizeImagesByLongerEdge → ResizeImageMaskNode → LTXVPreprocess]
        │
        ▼
[LTXVImgToVideoInplace (image_denoise_strength=0.7)]
        │
        ▼
[LTXVEmptyLatentAudio 121 frames @ 25fps batch 1]
        │
        ▼
[LTXVConditioning + CFGGuider]
        │
        ▼
[RandomNoise + KSamplerSelect (euler_ancestral_cfg_pp) + ManualSigmas]
        │
        ▼
[SamplerCustomAdvanced — PASS 1 LOW-RES]
        │
        ▼
[LTXVSeparateAVLatent → LTXVLatentUpsampler (2× upscale) → LTXVConcatAVLatent]
        │
        ▼
[LTXVImgToVideoInplace (image_denoise_strength=1.0) + LTXVCropGuides]
        │
        ▼
[KSamplerSelect (euler_cfg_pp) + ManualSigmas]
        │
        ▼
[SamplerCustomAdvanced — PASS 2 HIGH-RES REFINEMENT]
        │
        ▼
[VAEDecodeTiled → IMAGE batch]
        │
        ▼
[VHS_VideoCombine — h264-mp4 @ 24/25 fps]
```

## Required models

| Slot | File | Notes |
|---|---|---|
| Checkpoint | `ltx-2.3-22b-dev.safetensors` (or `ltx-2-19b-dev-fp8`) | bundles model+VAE+audio_VAE |
| Distilled LoRA | `ltx-2.3-22b-distilled-lora-384.safetensors` | **REQUIRED for fast sampling** |
| Text encoder | `gemma_3_12B_it_fp8_e4m3fn.safetensors` | LTXAVTextEncoderLoader, type=`ltx-2.3-22b-dev.safetensors` |
| Audio VAE | bundled in checkpoint | LTXVAudioVAELoader takes the same checkpoint file |
| Latent upscaler | `LatentUpscaleModelLoader` model | for 2× pass |

GGUF / older variant: `ltx-2-19b-distilled-lora-384.safetensors` for LTX 2.0.

## Active LoRAs (scene-specific, all LoRA stacks should mirror)

Common active set in donor workflows:
- `ltx-2.3-22b-distilled-lora-384.safetensors` (always, distillation enabler)
- `SexGod_Nudity_LTX23_v2_0.safetensors` (NSFW polish)
- `LTX-2.3 - Orgasm.safetensors`
- `msltx-3fingering-step00005000_comfy.safetensors`
- `LTX-2.3 - Ahegao Face v1.safetensors`
- `LTX-2.3 - Dildo Ride.safetensors`
- `LTX2.3-Rogue-Missionary-Cowgirl-v3.safetensors`
- `LTX2.3-NSFWMOTION_00750.safetensors`
- `LTX2.3_Crisp_Enhance.safetensors` (general detail boost)
- `LTX23-GalaxyAce.safetensors`
- `LTX2-i2v-SexyMove.safetensors`
- `nsfw_riding_backshot_frontshot_ltx23_v1.0.safetensors`
- `SexGod_BreastMassage_LTX23_v1.safetensors`
- `DR34ML4Y_LTXXX_PREVIEW_RC1.safetensors`

**No Sina-specific LTX 2.3 LoRA exists yet** — Sina face is preserved via the input image (i2v carries identity from frame 1).

## Default parameters

| Param | Value | Notes |
|---|---|---|
| Resolution | 1280 × 720 (or 720 × 1280 portrait) | LTXVPreprocess + ResizeImageMaskNode |
| Frames | 121 | LTXVEmptyLatentAudio (≈ 5s @ 25fps) |
| FPS internal | 25 | LTXVEmptyLatentAudio |
| FPS output | 24 | VHS_VideoCombine `frame_rate` (slight slow-mo) |
| Pass 1 sampler | `euler_ancestral_cfg_pp` | KSamplerSelect 67 |
| Pass 2 sampler | `euler_cfg_pp` | KSamplerSelect 77 |
| Pass 1 denoise | 0.7 | LTXVImgToVideoInplace (after first preprocess) |
| Pass 2 denoise | 1.0 | LTXVImgToVideoInplace (after upscale) |
| LTXVPreprocess | 18 | img_compression value |
| Output format | h264-mp4, yuv420p, crf 18 | VHS_VideoCombine |
| Output prefix | `video/LTX_2.3_i2v` | VHS_VideoCombine `filename_prefix` |

## Audio derived from prompt

LTX 2.3 generates synced audio from the prompt text — the prompt should describe both visuals AND sounds:
- "...with soft moaning sounds..."
- "...gentle whispers in the background..."
- "...rhythmic sounds matching the motion..."

No separate audio conditioning input needed. The `LTXVEmptyLatentAudio` allocates the audio latent space, and the text encoder fills both visual and audio conditioning.

## Variable inputs (per run)

| What | Where | Notes |
|---|---|---|
| Source image | LoadImage 269 | first frame for i2v |
| Positive prompt | CLIPTextEncode (proxy of subgraph 267) | scene + audio cues + `sinahohenheim` if face needs anchoring |
| Negative prompt | CLIPTextEncode 51 | standard low-quality blacklist |
| Frame count | LTXVEmptyLatentAudio `length` | 121 default → 5s @ 25fps |
| Resolution | ResizeImageMaskNode + LTXVPreprocess | typically 1280×720 |
| Seed | RandomNoise / SamplerCustomAdvanced | randomize |
| LoRA stack | LoraLoaderModelOnly chain | toggle scene LoRAs |
| Output prefix | VHS_VideoCombine 14000 | `video/LTX_2.3_i2v/SLUG/SLUG` |

## Code skeleton

```python
import json, copy, urllib.request, uuid, time, datetime, random

REF = "/workspace/.claude/skills/sina_video_ltx23/reference_workflow.json"
HOST = "http://localhost:8188"

def submit(prompt: str, source_image: str, *, seed: int = None,
           length: int = 121, prefix: str = None) -> str:
    with open(REF) as f:
        wf = json.load(f)  # API format expected
    if seed is None: seed = random.randint(0, 2**31)
    if prefix is None:
        prefix = f"video/ltx23/{datetime.date.today():%Y%m%d}_sina"

    for nid, node in wf.items():
        ct = node.get("class_type")
        inp = node.get("inputs", {})
        if ct == "LoadImage":
            inp["image"] = source_image
        if ct == "CLIPTextEncode" and "low quality" not in inp.get("text","").lower():
            inp["text"] = prompt
        if ct == "LTXVEmptyLatentAudio":
            inp["length"] = length
        if ct == "RandomNoise":
            inp["noise_seed"] = seed
        if ct in ("VHS_VideoCombine", "SaveVideo"):
            inp["filename_prefix"] = prefix

    payload = {"prompt": wf, "client_id": str(uuid.uuid4())}
    req = urllib.request.Request(f"{HOST}/prompt",
                                 data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)["prompt_id"]
```

## Alternative donor workflows

- `LTXEROSNSFW GOAT WF.json` — NSFW LTX (also subgraph-wrapped, identical inner structure)
- `LTX SFW GOAT.json` — SFW LTX
- `LTX_2.3 First And Last Frame.json` — first/last frame interpolation
- `SNP REAL Sven_LTX23_Loop_v2.json` — looping video variant
- `SNP ltx 2.3(2) (1).json` — alternate LTX 2.3 setup
- `CLSNP_LTX23_SECTIONED_12x5s.json` — **best for understanding internals** (368 nodes, 4 sections, no subgraph wrapping)

For unwrapped/full-detail LTX pipeline, prefer `CLSNP_LTX23_SECTIONED_12x5s.json` as donor when building variants.

## Common Pitfalls
_(empty — populate with experience. Likely candidates: subgraph proxyWidgets not propagating after graph→API conversion (must expand subgraph in UI first); LTX 2.3 vs 2.0 LoRA incompatibility (`ltx-2-19b` LoRAs don't work on `ltx-2.3-22b`); ManualSigmas values for pass 1 vs pass 2 must differ — pass 1 typically `[1.0 ... 0.0]`, pass 2 `[0.5 ... 0.0]`; LatentUpscaleModelLoader missing model causes OOM-like silent failure; gemma_3_12B text encoder requires significant RAM at fp8)_
