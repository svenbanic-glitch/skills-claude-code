---
name: video_extend
description: Extend existing video by sampling additional frames continuing from last frame. Use to make a 5s clip into 10s, 15s, etc. Triggers - "extend video", "make longer", "continue video", "verlängern".
tools: Bash, Read, Write
---

# video_extend

Video extension pipeline. Reference: `ClaudeCode Wan 2.2 EXTEND LONG VIDS ( NSFW) TOP.json` (copy at `reference_workflow.json`). Loads an existing video, extracts the last frame, runs WAN 2.2 i2v to generate a continuation, then concatenates with the source.

91 nodes, 21 active, 70 bypassed (lots of toggleable extension lengths). Uses `WanContextWindowsManual` (4 instances) for context-window-based long video — extension via overlapping windows rather than pure frame chaining.

## When to use
- User has existing 5s clip, wants 10s/15s/20s
- "Extend this video", "make it longer", "verlängern"
- When source video should be preserved exactly (not regenerated)
- When ad-hoc frame chaining is enough (vs full 12-section sectioned skill)

For from-scratch long-form generation: use `sectioned_video_long_form` skill instead.

## Pipeline stages

```
[LoadImage source_first_frame] (or VHS_LoadVideo source.mp4)
        │
        ▼
[Subgraph: WAN i2v sampling — generates continuation from last frame]
        │
        ├─→ [VAEDecode → IMAGE batch]
        │           │
        │           ▼
        │   [VHS_VideoCombine extension.mp4]
        │
        ├─→ [Frame Select last_frame] ──┐
        │                                ▼
        │                         [Next iteration's start image]
        │                                │
        ▼                                ▼
[WanContextWindowsManual ×4 — manages 4 overlapping context windows]
        │
        ▼
[Frames Concat: source frames + extension frames]
        │
        ▼
[Star_Show_Last_Frame — debug preview of seam]
        │
        ▼
[VHS_VideoCombine final extended.mp4]
```

3 separate `VHS_VideoCombine` outputs at 16 fps:
- Section 1 extension preview
- Section 2 extension preview  
- Final concatenated long video

## Required models

Same as `sina_video_wan22` skill:
- `wan2.2_i2v_A14b_high_noise_scaled_fp8_e4m3_lightx2v_4step_comfyui_1030.safetensors` (HIGH UNet)
- `wan2.2_i2v_A14b_low_noise_scaled_fp8_e4m3_lightx2v_4step_comfyui.safetensors` (LOW UNet)
- `nsfw_wan_umt5-xxl_fp8_scaled.safetensors` CLIP
- `wan_2.1_vae.safetensors` VAE

Subgraphs in this workflow likely wrap WAN's KSampler chain.

## WanContextWindowsManual pattern

The 4 `WanContextWindowsManual` nodes implement **sliding context windows**:
- Window 1: frames 0–80 (overlap with source)
- Window 2: frames 60–160 (50% overlap with W1)
- Window 3: frames 140–240
- Window 4: frames 220–320

Overlapping windows reduce seam artifacts. Each window samples independently with its own context, then frames are blended at overlap regions.

vs naive frame-chaining (last-frame-only): context windows produce smoother long-form because more than one frame conditions each new generation.

## Default parameters

| Param | Value | Notes |
|---|---|---|
| Output FPS | 16 | VHS_VideoCombine `frame_rate` |
| Context window size | typically 81 frames | per `WanContextWindowsManual` |
| Window overlap | typically 50% | configured per node |
| Total extended length | depends on # active windows | each window ≈ 5s |
| Inherits from `sina_video_wan22` | sampler/scheduler/cfg/steps | inside subgraphs |

For 10s output (2 windows): bypass W3, W4
For 15s output (3 windows): bypass W4
For 20s output: keep all 4

## Variable inputs (per run)

| What | Where | Notes |
|---|---|---|
| Source first frame | LoadImage 33 | or load video and extract |
| Per-window prompt | (inside subgraphs) | section descriptions |
| Window count | enable/bypass `WanContextWindowsManual` nodes | 4 max |
| Output prefix | VHS_VideoCombine 32/81/88 | `[slug]/extended` |

## Code skeleton

```python
import json, copy, urllib.request, uuid, time, datetime, random

REF = "/workspace/.claude/skills/video_extend/reference_workflow.json"
HOST = "http://localhost:8188"

def submit(source_image_or_video: str, target_seconds: int = 10,
           prompts: list[str] = None, seed: int = None) -> str:
    """
    target_seconds: 10, 15, 20 supported (= 2, 3, 4 active context windows)
    prompts: list of per-window prompts; if None, uses identical default for all windows
    """
    with open(REF) as f:
        wf = json.load(f)
    if seed is None: seed = random.randint(0, 2**31)

    n_windows = max(1, min(4, target_seconds // 5))
    if prompts is None:
        prompts = ["Continue the scene naturally, same character, same action."] * n_windows

    # Bypass windows beyond n_windows by setting their mode to 4 (graph format).
    # In API format, simply skip including those nodes.
    # (Explicit bypassing requires graph-format manipulation — see workflow_factory.)

    for nid, node in wf.items():
        ct = node.get("class_type")
        inp = node.get("inputs", {})
        if ct == "LoadImage":
            inp["image"] = source_image_or_video
        if ct == "VHS_VideoCombine":
            inp["filename_prefix"] = f"video/extended/{datetime.date.today():%Y%m%d}_extend{target_seconds}s"
        # KSampler seeds: increment per window for diversity but match for continuity testing
        if ct == "KSampler" or ct == "KSamplerAdvanced":
            inp["seed" if "seed" in inp else "noise_seed"] = seed

    payload = {"prompt": wf, "client_id": str(uuid.uuid4())}
    req = urllib.request.Request(f"{HOST}/prompt",
                                 data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)["prompt_id"]
```

## Alternative donor workflows

- `Sven I2V EXTEND LONG VIDS ( NSFW) TOP.json` — Sven-prefixed variant (alt non-ClaudeCode)
- `I2V Infinite extender - SUBS - Icekiub v1.json` — infinite extender with subs overlay
- `SNPNSFWWANEXTENDEDSVEN.json` — alt naming
- `SNPLTXEXTENDEDNSFWLOOP.json` — **LTX 2.3 variant** for extension (use this if working in LTX backend)

For LTX-based extension (loop-style): use `SNPLTXEXTENDEDNSFWLOOP.json` as donor instead. The pattern differs — LTX uses "First and Last Frame" interpolation rather than context windows.

## Common Pitfalls
_(empty — populate with experience. Likely candidates: WanContextWindowsManual overlap region producing visible seams when prompts differ between windows; extracting last frame from already-extended video accumulates artifacts (limit chained extensions to 2–3 generations max); source video FPS mismatch with output (16 fps) causing time distortion in concatenation; bypassed window's inputs not properly disconnecting causing graph errors; Frame Select node using wrong frame index when source video has variable frame rate; mixing WAN-extended sections with LTX-extended sections requires VAE re-encoding step (different latent spaces))_
