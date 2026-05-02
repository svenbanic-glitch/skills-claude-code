---
name: sectioned_video_long_form
description: Generate long-form video by stitching multiple 5s segments. Use for videos > 10 seconds. Supports both WAN 2.2 and LTX 2.3 backends. Triggers - "long video", "60 second video", "sectioned", "sliding window", "frame chaining", "lange video".
tools: Bash, Read, Write
---

# sectioned_video_long_form

Long-form video pipeline. Two donors stored alongside this skill:
- `reference_workflow_wan.json` ← WAN 2.2 backend (`CLSNPNWANSFW_SECTIONED_12x5s_FIXED.json`)
- `reference_workflow_ltx.json` ← LTX 2.3 backend (`CLSNP_LTX23_SECTIONED_12x5s.json`)

Pattern: 12 segments × 5s each, last frame of section N becomes first frame of section N+1. Total 60s. Supports both WAN 2.2 and LTX 2.3 as the underlying generator.

## When to use
- Videos > 10s (single-pass WAN/LTX max ~10s)
- "60 second video", "minute long", "lange video", "extended scene"
- When you need ad-hoc segment count (8×5s = 40s, 6×5s = 30s, etc.)
- Continuity-critical scenes (each section continues naturally from the previous)

## Backend choice

| Backend | Best for | Reference |
|---|---|---|
| **WAN 2.2** | Realism focus, NSFW with FaceSwap LoRA, sharper details | `reference_workflow_wan.json` |
| **LTX 2.3** | Coherent longer motions, audio-from-prompt, smoother camera | `reference_workflow_ltx.json` |

Default: **LTX 2.3** for >30s (better motion coherence).
WAN 2.2 for <30s (better per-frame realism).

## Pattern: frame chaining

```
Section 1: input_image → [generate 5s] → frame 1.last
Section 2: frame 1.last → [generate 5s] → frame 2.last
Section 3: frame 2.last → [generate 5s] → frame 3.last
...
Section N: frame (N-1).last → [generate 5s] → final
─────────────────────────────────────────────────
Concat all section videos → final long-form output
```

Each section runs the same pipeline (WAN i2v or LTX i2v) but with:
- Different first frame (chained from previous section)
- Different prompt (per-section motion description)
- Independent seed (or sequential for determinism)

## LTX 2.3 sectioned structure (donor analysis)

`CLSNP_LTX23_SECTIONED_12x5s.json` actually shows **4 sections** wired in (with template scaling to 12). 368 nodes total, 135 active, 233 bypassed (= 8 inactive section blocks).

Per-section node IDs follow a pattern: `[section_index][slot]` (e.g. `1010` = section 1 LoRA loader, `2010` = section 2 LoRA loader, etc.).

Per section:
- 1 `LoraLoaderModelOnly` chain (3 LoRAs typical: distilled + scene LoRA + style)
- 1 `CLIPTextEncode` with section-specific prompt
- 1 `LTXVImgToVideoInplace` (denoise 0.7) → low-res sampling
- 1 `LTXVLatentUpsampler` (2× latent upscale)
- 1 `LTXVImgToVideoInplace` (denoise 1.0) → high-res sampling
- 1 `Star_Show_Last_Frame` → extracts last frame for next section
- 1 `ImageBatch` → accumulates section frames
- 2 `SamplerCustomAdvanced` (pass 1 + pass 2)
- 1 `VAEDecodeTiled`

Final concatenation via single `VHS_VideoCombine` (frame_rate 24, prefix `video/LTX23/sectioned/final`).

## WAN 2.2 sectioned structure

`CLSNPNWANSFW_SECTIONED_12x5s_FIXED.json` mirror with WAN backend per section:
- 1 high-noise UNet stage + 1 low-noise UNet stage per section (= 24 KSamplers total)
- Both UNet stages need their own LoRA stack (HIGH + LOW pair) per section
- Frame chaining via last-frame extraction
- Concat via VHS_VideoCombine

## Required models (LTX 2.3 backend)

See `sina_video_ltx23` skill — same model set:
- `ltx-2.3-22b-dev.safetensors` checkpoint
- `ltx-2.3-22b-distilled-lora-384.safetensors` LoRA
- `gemma_3_12B_it_fp8_e4m3fn.safetensors` text encoder
- LatentUpscaleModelLoader model

## Required models (WAN 2.2 backend)

See `sina_video_wan22` skill — same model set:
- `wan2.2_i2v_A14b_high_noise_scaled_fp8_e4m3_lightx2v_4step_comfyui_1030.safetensors` (HIGH UNet)
- `wan2.2_i2v_A14b_low_noise_scaled_fp8_e4m3_lightx2v_4step_comfyui.safetensors` (LOW UNet)
- `nsfw_wan_umt5-xxl_fp8_scaled.safetensors` CLIP
- `wan_2.1_vae.safetensors` VAE

## Per-section prompts (template)

```
[Section 1 | 0s-5s] Initial scene establishment. Sina is in [location], wearing [outfit]. She [opening motion].
[Section 2 | 5s-10s] Continuation. She [next motion], camera [movement]. Same character, same location.
[Section 3 | 10s-15s] Beat change or escalation. [new action]. Continues from Section 2.
[Section 4 | 15s-20s] [next motion]. Same character, same location.
... (12 sections total for 60s)
```

Critical: each prompt MUST end with "Continues from Section N-1, same character, same location" or similar continuity anchor — otherwise model drifts between sections.

## Color drift mitigation

Long-form generation drifts color/contrast across sections. Donors include patches but they're toggle-only:
- **Color Match MVGD** — anchors color statistics of section N to section 1
- **IC-LoRA Union (LTX 2.3 only)** — `ltx-2-19b-ic-lora-union-control-ref0.5.safetensors` provides cross-section reference conditioning
- **Periodic re-anchor** — every 3 sections, force re-encode from a clean reference frame instead of last-frame

Default: Color Match MVGD enabled. Toggle IC-LoRA Union if color drift > 10% perceived.

## Default parameters per section

Same as `sina_video_wan22` or `sina_video_ltx23` defaults — see those skills.

Output: 12 separate section MP4s (per section `VHS_VideoCombine`) + 1 final concatenated MP4.

## Variable inputs (per run)

| What | Where | Notes |
|---|---|---|
| Initial source image | LoadImage 30 | first frame of section 1 |
| Per-section prompts | CLIPTextEncode 1021, 2021, 3021, ..., 12021 | one per section |
| Section count | enable/bypass section blocks | bypass to skip sections |
| Negative prompt | CLIPTextEncode 51 | shared across sections |
| Per-section LoRA | section-prefixed LoraLoaderModelOnly nodes | swap by `lora_name` |
| Output filename | final VHS_VideoCombine | `video/long_form/[slug]/final` |

## Code skeleton

```python
import json, copy, urllib.request, uuid, time, datetime, random

WAN_REF = "/workspace/.claude/skills/sectioned_video_long_form/reference_workflow_wan.json"
LTX_REF = "/workspace/.claude/skills/sectioned_video_long_form/reference_workflow_ltx.json"
HOST = "http://localhost:8188"

def submit_long(prompts: list[str], source_image: str, *, backend: str = "ltx",
                base_seed: int = None) -> str:
    """prompts: 12 strings, one per section. Backend: 'wan' or 'ltx'."""
    ref = LTX_REF if backend == "ltx" else WAN_REF
    with open(ref) as f:
        wf = json.load(f)
    if base_seed is None: base_seed = random.randint(0, 2**31)

    # Section prompts in donor: nodes 1021, 2021, 3021, 4021, ... (graph format).
    # In API format: same node ids preserved.
    for nid, node in wf.items():
        ct = node.get("class_type")
        inp = node.get("inputs", {})
        if ct == "LoadImage":
            inp["image"] = source_image
        if ct == "CLIPTextEncode":
            # Match by section-prefix node id
            sec = None
            for s in range(1, 13):
                if str(nid).startswith(str(s)) and str(nid).endswith("021"):
                    sec = s
                    break
            if sec is not None and sec <= len(prompts):
                inp["text"] = prompts[sec-1]
        if ct == "RandomNoise":
            # per-section seed = base_seed + section_index for determinism
            inp["noise_seed"] = base_seed + (int(nid) // 1000)
        if ct == "VHS_VideoCombine":
            inp["filename_prefix"] = f"video/long_form/{datetime.date.today():%Y%m%d}_sectioned"

    payload = {"prompt": wf, "client_id": str(uuid.uuid4())}
    req = urllib.request.Request(f"{HOST}/prompt",
                                 data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)["prompt_id"]
```

**Runtime:** 12 sections × ~3–6 min each = 40–70 min total on L4. Plan accordingly. For shorter total: bypass unused section blocks.

## Alternative donor workflows

- `ClaudeCode wan2.2 i2vNSFW_SECTIONED_12x5s also jede section kann man solange machen wie an will loras müssen halt an sein.json` — WAN sectioned with per-section LoRA flexibility note
- `ClaudeCode LTX 2.3 NSFW_SECTIONED_12x5s also jede section kann man solange machen wie an will loras müssen halt an sein.json` — LTX 2.3 sectioned alt
- `CLSNPNSFW_SECTIONED_12x5s.json` — earlier WAN sectioned (pre-FIXED)

## Common Pitfalls
_(empty — populate with experience. Likely candidates: section drift accumulation past section 6 — re-anchor with reference frame; per-section LoRA mismatch causes flicker between sections; bypassed sections still occupying VRAM if not properly excluded; final concat losing audio if per-section audio differs; LTX vs WAN intermediate frame interpretation — last-frame extraction node names differ; VHS_VideoCombine final MP4 silently truncated if disk space < projected size; color drift mitigation patches conflict if both Color Match and IC-LoRA enabled simultaneously)_
