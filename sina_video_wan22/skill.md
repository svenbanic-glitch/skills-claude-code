---
name: sina_video_wan22
description: Generate NSFW image-to-video using WAN 2.2 with Sina character. Use when user requests video generation with WAN 2.2, image-to-video conversion. Triggers - "WAN video", "WAN 2.2", "i2v", "image to video".
---

# sina_video_wan22

Reference pipeline: `CL GOAT Sven NSFW_VIDEO_WAN2.2.json` (copy at `reference_workflow.json` next to this skill).

Original is in graph format (subgraph-based). 93 nodes total, 13 active, 80 bypassed alternatives. Subgraphs wrap the sampling logic and image-prep logic — proxyWidgets expose internal params.

## Pipeline stages

```
[Image Input + Resize subgraph (130)]
        │ (image, width, height)
        ▼
[CLIP umt5-xxl wan]    [VAE wan_2.1]
        │                   │
        ▼                   ▼
[CLIPTextEncode positive (133)]
[CLIPTextEncode negative (127)]
        │
        ▼
[WanImageToVideo (129)]  ← width=1280, height=720, length=161, batch_size=1
        │
        ▼ (positive, negative cond + latent)
[UNETLoader HIGH (123)] → [Power Lora Loader HIGH (131)] ┐
[UNETLoader LOW  (124)] → [Power Lora Loader LOW  (132)] ┤
                                                          ▼
                                            [Sampler subgraph (125)]
                                                          │
                                                          ▼ (IMAGE frames)
                                                   [RIFE VFI (128) ×2]
                                                          │
                                                          ▼
                                            [VHS_VideoCombine (120)]
                                                          │
                                                          ▼
                                  /output/video/wan22/base/base_NNNNN.mp4
```

## Required models

| Slot | File | Notes |
|---|---|---|
| UNet HIGH noise | `wan2.2_i2v_A14b_high_noise_scaled_fp8_e4m3_lightx2v_4step_comfyui_1030.safetensors` | in `/models/diffusion_models/` or `/models/unet/` |
| UNet LOW noise | `wan2.2_i2v_A14b_low_noise_scaled_fp8_e4m3_lightx2v_4step_comfyui.safetensors` | same |
| CLIP | `nsfw_wan_umt5-xxl_fp8_scaled.safetensors` (type=`wan`, device=`default`) | in `/models/text_encoders/` |
| VAE | `wan_2.1_vae.safetensors` | in `/models/vae/` |

WAN 2.2 always runs as **HIGH+LOW two-stage** — both UNets must be loaded, both LoRA stacks must be on, both must be wired into the sampler subgraph (it has `model` and `model_1` inputs).

## Active LoRAs (both stacks must mirror each other)

### HIGH stack (node 131, fed into HIGH UNet)
| LoRA | Strength |
|---|---|
| `WAN2.2-HighNoise_Pussyv1-I2V_T2V.safetensors` | 1.0 |
| `I2V-WAN2.2-EdibleAnus-HighNoise-1.1_-000050.safetensors` | 1.0 |
| `slop_twerk_HighNoise_merged3_7_v2.safetensors` | 0.2 |
| `WANExpreimentialGOATNSFW-22-H-e8.safetensors` | 0.3 |
| `WANDR34ML4Y_I2V_14B_HIGH_V2.safetensors` | 0.2 |

### LOW stack (node 132, fed into LOW UNet)
| LoRA | Strength |
|---|---|
| `WAN2.2-LowNoise_Pussyv1-I2V_T2V.safetensors` | 1.0 |
| `Sensual_fingering_v1_low_noise.safetensors` | 0.7 |
| `I2V-WAN2.2-EdibleAnus-LowNoise-1.1_-000060.safetensors` | 0.3 |
| `WANExpreimentialGOATNSFW-22-L-e8.safetensors` | 0.2 |
| `WANDR34ML4Y_I2V_14B_LOW_V2.safetensors` | 0.3 |

**Pairing rule:** For every HIGH LoRA there should be a matching LOW LoRA (same scene/effect). Mismatched stacks cause flicker between sampling stages. Bypassed alternatives in the original cover: BouncyWalk, Pornmaster Slow Twerk, Pornmaster Bukkake, FaceDownAssUp, Orgasm, BreastPlay, Ultimate Blowjob — toggle on as needed but always toggle BOTH HIGH+LOW.

## Default parameters

| Param | Value | Source |
|---|---|---|
| Resolution | 1280 × 720 | WanImageToVideo node 129 |
| Length (frames) | 161 | WanImageToVideo node 129 |
| Batch size | 1 | WanImageToVideo node 129 |
| RIFE multiplier | 2 (frames doubled) | RIFE VFI node 128, ckpt `rife47.pth`, scale=1.0, fast_mode=True, ensemble=True, clear_cache_after_n=10 |
| Output FPS | 30 | VHS_VideoCombine node 120 |
| Output format | h264-mp4, yuv420p, crf=18 | VHS_VideoCombine |
| Output prefix | `video/wan22/base/base` | VHS_VideoCombine |

**Sampler params** are inside subgraph 125 (proxyWidgets to internal nodes 110 (shift), 111 (shift), 113, 114, 115 (cfg, sampler_name, scheduler), 116 (noise_seed, control_after_generate, cfg, sampler_name, scheduler)). The subgraph runs HIGH UNet then LOW UNet sequentially via two `KSamplerAdvanced` instances — start_at_step / end_at_step split the schedule between them. To change sampler/scheduler/cfg/seed, expand the subgraph in the UI or convert to API format and edit the resolved internal nodes.

## Variable inputs (per run)

| What | Where | Default |
|---|---|---|
| Input image | Image-input subgraph 130 → internal LoadImage node 117 (proxy) | (must be set per run) |
| Positive prompt | CLIPTextEncode node 133 → `text` widget | "sensual_fingering, fingering her vagina with her two middle fingers..." (replace) |
| Seed | Sampler subgraph 125 → proxy to node 116 `noise_seed` | (randomize or fix) |
| Frame count override | WanImageToVideo node 129 → `length` | 161 |
| Resolution | WanImageToVideo node 129 → `width`/`height` | 1280×720 |
| Output prefix | VHS_VideoCombine node 120 → `filename_prefix` | `video/wan22/base/base` |

## Standard negative prompt (kept verbatim)

The Chinese WAN-default negative is in CLIPTextEncode node 127 — keep it, it's the official WAN 2.2 anti-artifact prompt. English additions appended:

```
色调艳丽，过曝，静态，细节模糊不清，字幕，风格，作品，画作，画面，静止，整体发灰，最差质量，低质量，JPEG压缩残留，丑陋的，残缺的，多余的手指，画得不好的手部，画得不好的脸部，畸形的，毁容的，形态畸形的肢体，手指融合，静止不动的画面，杂乱的背景，三条腿，背景人很多，倒着走,morphing, warping, flickering, jittering, sudden changes, face
```

## Sina character integration

The reference workflow does NOT include a Sina LoRA. To make the character Sina:
- Add Sina face/body LoRA into BOTH HIGH and LOW stacks at matching strengths (typical 0.6–0.9)
- Best Sina LoRA for WAN 2.2 i2v: `SinaWanFaceSwap2.2_000001100_low_noise.safetensors` (LOW only — HIGH version not trained for face swap)
- For i2v, the input image already carries Sina's appearance — face swap LoRA is mainly insurance against drift in long sequences
- Trigger word in prompt: `sinahohenheim` (per global CLAUDE.md)

## Code skeleton (API submission)

```python
import json, copy, urllib.request, uuid, time

REF = "/workspace/.claude/skills/sina_video_wan22/reference_workflow.json"
HOST = "http://localhost:8188"

def load_reference():
    with open(REF) as f:
        return json.load(f)

def submit_graph(graph_wf: dict, prompt: str, seed: int, length: int = 161,
                 input_image_path: str = None, out_prefix: str = None) -> str:
    """
    The reference is in GRAPH format. ComfyUI's /prompt expects API format.
    Easiest path: open in UI, "Save (API Format)" once, save next to this skill
    as reference_api.json — then this function works on the API dict.
    For graph→API: see workflow_factory skill.
    """
    wf = copy.deepcopy(graph_wf)

    # ... convert graph→api here ...
    # then mutate by class_type:
    api = wf  # placeholder — assume already API format

    for nid, node in api.items():
        ct = node.get("class_type")
        inp = node.get("inputs", {})
        if ct == "CLIPTextEncode" and len(inp.get("text", "")) > 50 and "色调" not in inp["text"]:
            inp["text"] = prompt  # positive (heuristic: not the Chinese negative)
        if ct == "WanImageToVideo":
            inp["length"] = length
        if ct == "VHS_VideoCombine" and out_prefix:
            inp["filename_prefix"] = out_prefix
        if ct == "KSamplerAdvanced":
            inp["noise_seed"] = seed
        if ct == "LoadImage" and input_image_path:
            inp["image"] = input_image_path  # filename relative to /input/

    payload = {"prompt": api, "client_id": str(uuid.uuid4())}
    req = urllib.request.Request(f"{HOST}/prompt",
                                 data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)["prompt_id"]

def poll(prompt_id: str, timeout=1800, interval=5):
    deadline = time.time() + timeout
    while time.time() < deadline:
        with urllib.request.urlopen(f"{HOST}/history/{prompt_id}") as r:
            hist = json.load(r)
        if prompt_id in hist:
            return hist[prompt_id]
        time.sleep(interval)
    raise TimeoutError(prompt_id)
```

**Note on graph format:** Subgraphs (the UUID-typed nodes 125 and 130) need ComfyUI to expand them into their internal nodes when converted to API format. The cleanest way: open the workflow in the UI once, click "Save (API Format)" → drop the resulting JSON next to `reference_workflow.json` as `reference_api.json` and use that as the working copy.

## Performance expectations on L4 (23GB VRAM)

- 1280×720 × 161 frames × 4-step lightx2v distilled — full pipeline ~3–6 min/video
- VRAM headroom is tight: keep `weight_dtype=fp8_e4m3fn` on both UNets, no extra LoRAs beyond the active stack
- If OOM: drop length to 81 frames OR resolution to 960×544

## Common Pitfalls

_(empty — populate as issues are encountered. Candidates: HIGH/LOW LoRA mismatch flicker, subgraph proxyWidgets not propagating after API conversion, RIFE multiplier vs frame_rate confusion in VHS_VideoCombine output duration, missing CLIP_VISION_OUTPUT input on WanImageToVideo, input image aspect ratio mismatch with width/height)_
