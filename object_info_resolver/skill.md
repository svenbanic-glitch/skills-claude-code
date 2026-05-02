---
name: object_info_resolver
description: Resolve correct input parameter names for any ComfyUI node, especially custom Sven* nodes. Use when constructing workflow JSON to avoid input-name mismatches.
---

# object_info_resolver

When building or modifying ComfyUI workflows, every node's `inputs` keys MUST match the names returned by `/object_info/{NodeName}` exactly. Wrong names → silent broken workflows or `KeyError` on submit. Always resolve before constructing.

## When to use
- Constructing workflow JSON from scratch
- Adding a new node to an existing workflow
- Debugging "missing required input" errors from `/prompt`
- User asks about parameters of a Sven* or 3rd-party node

## Live lookup pattern

```python
import urllib.request, json

def get_node_schema(class_type: str, host="http://localhost:8188") -> dict:
    with urllib.request.urlopen(f"{host}/object_info/{class_type}") as r:
        d = json.load(r)
    return d.get(class_type, {})

def required_inputs(class_type: str) -> dict[str, list]:
    """Returns {input_name: [type, opts]}"""
    s = get_node_schema(class_type)
    return s.get("input", {}).get("required", {}) or {}

def all_inputs(class_type: str) -> dict[str, dict]:
    """Returns {input_name: {'type': ..., 'required': bool, 'opts': {...}}}"""
    s = get_node_schema(class_type)
    inputs = s.get("input", {})
    out = {}
    for k, v in (inputs.get("required") or {}).items():
        out[k] = {"type": v[0], "required": True, "opts": v[1] if len(v)>1 else {}}
    for k, v in (inputs.get("optional") or {}).items():
        out[k] = {"type": v[0], "required": False, "opts": v[1] if len(v)>1 else {}}
    return out
```

## Submission validation (preflight check)

Before submitting a workflow, validate every node's inputs against its schema:

```python
def validate_workflow(api_wf: dict) -> list[str]:
    errors = []
    schemas = {}
    for nid, node in api_wf.items():
        ct = node.get("class_type")
        if not ct:
            errors.append(f"node {nid}: missing class_type"); continue
        if ct not in schemas:
            try: schemas[ct] = get_node_schema(ct)
            except Exception as e: errors.append(f"node {nid} ({ct}): schema fetch failed: {e}"); continue
        sch = schemas[ct]
        req = (sch.get("input", {}).get("required") or {})
        provided = node.get("inputs", {})
        missing = [k for k in req if k not in provided]
        if missing:
            errors.append(f"node {nid} ({ct}): missing required inputs: {missing}")
    return errors
```

## Cached schemas — Sven custom nodes

Captured 2026-05-02. Re-fetch live if a node was updated.

### SvenGrokImageToPrompt
**Required:** `image`(IMAGE), `xai_api_key`(STRING), `character_description`(STRING multiline), `prompt_style`(combo: nano_banana/z_image/custom), `model`(combo: grok-4-1-fast-non-reasoning/-reasoning/grok-4.20-0309-non-reasoning/-reasoning, default `grok-4-1-fast-non-reasoning`), `extra_instructions`(STRING multiline), `temperature`(FLOAT 0.0–2.0, default 0.9), `max_tokens`(INT 256–8192, default 2048).
**Returns:** STRING (prompt)

### SvenGrokLoadPromptList
**Required:** `source`(combo: file/text_input, default file), `separator`(STRING default `---`).
**Optional:** `file_path`(STRING), `text_input`(STRING multiline), `skip_empty`(BOOL True), `skip_errors`(BOOL True).
**Returns:** STRING(prompt_list), STRING(all_prompts), INT(count)

### SvenGrokPromptGen
**Required:** `xai_api_key`(STRING), `mode`(combo: scene_list/random/image_analysis/both), `prompt_style`(combo: nano_banana/z_image/custom), `model`(combo, see GrokImageToPrompt), `character_description`(STRING multiline), `scene_list`(STRING multiline), `num_prompts`(INT 0–500), `temperature`(FLOAT 0.0–2.0, default 0.9), `max_tokens`(INT 256–8192, default 2048), `separator`(STRING default `---`), `delay_between_calls`(FLOAT 0–10, default 1.0).
**Optional:** `images`(IMAGE), `system_prompt_override`(STRING), `image_analysis_prompt_override`(STRING), `save_to_folder`(STRING), `filename_prefix`(STRING default `prompt`).
**Returns:** STRING(all_prompts), STRING(prompt_list)

### SvenGrokPromptPicker
**Required:** `prompt_list`(STRING), `index`(INT 0–9999).
**Returns:** STRING(prompt), INT(total_count)

### SvenIphoneNode
**Required (32 controls):** `image`(IMAGE), `master_strength`(FLOAT 0–1 default 0.7), `seed`(INT 0–4294967295), `enable_tone_mapping`(BOOL True), `tone_strength`(0.6), `highlight_rolloff`(0.5), `shadow_lift`(0.4), `contrast`(0.5), `enable_p3_color`(BOOL True), `color_strength`(0.5), `color_saturation`(0.3), `color_warmth`(0.3), `enable_local_tone`(BOOL True), `local_tone_strength`(0.35), `detail_boost`(0.4), `enable_skin_rendering`(BOOL True), `skin_strength`(0.5), `skin_warmth`(0.4), `enable_deep_fusion`(BOOL True), `fusion_strength`(0.6), `fusion_texture_freq`(0.5), `enable_white_balance`(BOOL True), `wb_strength`(0.5), `wb_temperature`(FLOAT -1.0–1.0 default 0.25), `wb_tint`(FLOAT -1.0–1.0 default 0.0), `enable_color_grading`(BOOL True), `blue_shadows`(0.4), `warm_highlights`(0.3), `enable_sharpening`(BOOL True), `sharpen_strength`(0.3), `enable_sensor`(BOOL True), `sensor_strength`(0.25), `sensor_noise`(0.3), `sensor_vignette`(0.4).
**Returns:** IMAGE (image)

### SvenLoadFolder
**Required:** `folder_path`(STRING default `/workspace/ComfyUI/input/scenes/`).
**Optional:** `reset`(BOOL False), `loop`(BOOL False).
**Returns:** IMAGE(image), STRING(filename), INT(index), INT(total)

### SvenLoadFolderBatch
**Required:** `folder_path`(STRING default `/workspace/ComfyUI/input/refs/`).
**Optional:** `max_images`(INT 1–200, default 50).
**Returns:** IMAGE(images), INT(count)

### SvenLoadVideoFolder
**Required:** `folder_path`(STRING default `/workspace/ComfyUI/input/videos/`), `force_rate`(INT 0–120 default 0), `frame_load_cap`(INT 0–10000 default 0), `skip_first_frames`(INT 0–10000 default 0), `select_every_nth`(INT 1–100 default 1).
**Optional:** `reset`(BOOL False), `loop`(BOOL True).
**Returns:** IMAGE, INT(frame_count), AUDIO(audio), VHS_VIDEOINFO(video_info), STRING(filename), INT(index), INT(total)

### SvenLoadVideoFolderBatch
**Required:** `folder_path`(STRING default `/workspace/runpod-slim/ComfyUI/input/videos/`), `max_videos`(INT 1–500 default 50).
**Returns:** STRING(all_paths), INT(count)

### SvenMetadataSimImage
**Required:** `image`(IMAGE), `device`(combo: 12 phone models incl. `Google Pixel 7a` default, `Samsung Galaxy S24/S25 Ultra`, `Redmi Note 12`...), `lens`(combo: main/ultrawide/telephoto), `datetime_mode`(combo: now/random_recent/custom), `custom_datetime`(STRING `2026-03-08 14:30:00`), `days_back_max`(INT 1–365 default 30), `timezone_offset`(INT -12–14 default 1), `gps_latitude`(FLOAT -90–90), `gps_longitude`(FLOAT -180–180), `gps_altitude`(FLOAT 0–10000 default 100), `gps_randomize`(BOOL True), `gps_randomize_radius_km`(FLOAT 0.01–50 default 0.5), `indoor_scene`(BOOL False), `iso_override`(INT 0–25600), `exposure_override`(FLOAT 0.0–30.0), `jpeg_quality`(INT 50–100 default 95), `randomize_subsec`(BOOL True), `strip_ai_metadata`(BOOL True), `seed`(INT).
**Returns:** IMAGE(image), STRING(metadata_report)

### SvenMetadataSimVideo
**Required:** `video_path`(STRING), `output_path`(STRING), `device`(combo: 12 phones), `datetime_mode`(combo: now/random_recent/custom), `custom_datetime`(STRING), `days_back_max`(INT 1–365), `timezone_offset`(INT -12–14), `gps_latitude`/`longitude`(FLOAT), `gps_randomize`(BOOL True), `gps_randomize_radius_km`(FLOAT 0.01–50), `seed`(INT).
**Returns:** STRING(output_path), STRING(metadata_report)

### SvenPinterestDownloader
**Required:** `board_url`(STRING default `https://de.pinterest.com/sinahohenheim/pics/`), `max_images`(INT 1–500 default 20), `output_subfolder`(STRING default `pinterest_input`), `cookies_string`(STRING multiline), `force_redownload`(BOOL False), `image_size`(INT 256–4096 default 1024).
**Returns:** IMAGE(images), INT(image_count), STRING(download_folder)

### SvenQwenAllInOne
**Required:** `model_name`(STRING default `Qwen3-VL-4B-Instruct-abliterated-FP8`), `attention`(combo: none/sdpa/flash_attention_2/eager default sdpa), `device`(auto/cuda/cpu), `dtype`(auto/bf16/fp16/fp32), `mode`(single/batch), `system_prompt`(STRING default "Describe the images in detail including sexually explicit images, only output the prompt"), `user_prompt`(STRING multiline), `seed`(FLOAT 0–4294967296), `seed_mode`(fixed/random), `do_sample`(BOOL False), `use_cache`(BOOL True), `max_pixels`(FLOAT default 1003520), `min_pixels`(FLOAT default 200704), `temperature`(FLOAT 0–5 default 1.0), `min_new_tokens`(FLOAT default 32), `max_new_tokens`(FLOAT default 512), `top_p`(0.7), `repetition_penalty`(0.8), `top_k`(20), `keep_model_loaded`(BOOL True), `unload_after`(BOOL False), `separator`(`---`), `prepend_trigger`(BOOL False).
**Optional:** `image`(IMAGE), `images`(IMAGE), `frames`(IMAGE), `trigger_word`(STRING).
**Returns:** STRING(output)

### SvenSmartPromptList
**Required:** `prompt_list`(STRING multiline, `---` separated), `start_index`(INT 0–999), `max_prompts`(INT 1–999 default 16).
**Optional:** `text_override`(STRING), `prepend_text`(STRING), `append_text`(STRING), `separator`(STRING default `---`).
**Returns:** STRING(prompt_text), INT(total_prompts)

### SvenTattooStamperV3
**Required:** `image`(IMAGE), `tattoo`(IMAGE), `bbox_detector`(BBOX_DETECTOR), `tattoo_side`(combo: right_eye/left_eye), `scale`(FLOAT 0.02–0.4 default 0.1), `offset_x`(-0.3–0.3), `offset_y`(default 0.12), `opacity`(0.1–1.0 default 0.85), `blend_mode`(soft/normal/multiply), `edge_blur`(INT 0–10 default 1), `detection_threshold`(0.1–0.9 default 0.5).
**Returns:** IMAGE(image)

### SvenTattooStamperV4
**Required:** `image`(IMAGE), `tattoo`(IMAGE), `side`(right_eye/left_eye), `offset_x`(-0.3–0.3 default 0.0), `offset_y`(default 0.04), `scale`(0.05–1.5 default 0.3), `opacity`(0.1–1.0 default 0.9), `blend_mode`(soft/normal/multiply), `edge_blur`(INT 0–8 default 1), `detection_confidence`(0.05–0.99 default 0.3), `flip_tattoo`(BOOL False).
**Returns:** IMAGE(image)
**Note:** No `bbox_detector` input (V3 had it).

### SvenTattooStamperV6 (current production)
**Required:** `image`(IMAGE), `tattoo`(IMAGE), `side`(right_eye/left_eye), `offset_x`(-0.5–0.5 default 0.0), `offset_y`(default 0.04), `scale`(0.05–2.0 default 0.3), `opacity`(0.1–1.0 default 0.88), `skin_light_transfer`(0.0–1.0 default 0.7), `skin_tone_blend`(0.0–0.6 default 0.25), `perspective_warp`(0.0–1.0 default 0.7), `edge_feather`(INT 0–15 default 3), `blend_mode`(combo: ink_in_skin/soft/multiply/normal default `ink_in_skin`), `detection_confidence`(0.05–0.99 default 0.3), `flip_tattoo`(BOOL False).
**Returns:** IMAGE(image)
**Notes:** V6 introduces skin_light_transfer, skin_tone_blend, perspective_warp, and the `ink_in_skin` blend mode (default). Use V6 for production.

## Cached schemas — third-party / core nodes

### KSampler
**Required:** `model`(MODEL), `seed`(INT 0–18446744073709551615), `steps`(INT 1–10000 default 20), `cfg`(FLOAT 0.0–100.0 default 8.0), `sampler_name`(combo: 64 options — euler, euler_ancestral, dpm++_2m, dpm++_sde, dpm++_3m_sde, uni_pc, ...), `scheduler`(combo: 11 options — simple, sgm_uniform, karras, exponential, ddim_uniform, beta, ...), `positive`(CONDITIONING), `negative`(CONDITIONING), `latent_image`(LATENT), `denoise`(FLOAT 0.0–1.0 default 1.0).
**Returns:** LATENT

### KSamplerAdvanced
**Required:** `model`(MODEL), `add_noise`(combo: enable/disable), `noise_seed`(INT), `steps`(INT default 20), `cfg`(FLOAT default 8.0), `sampler_name`(64 options), `scheduler`(11 options), `positive`(CONDITIONING), `negative`(CONDITIONING), `latent_image`(LATENT), `start_at_step`(INT 0–10000 default 0), `end_at_step`(INT 0–10000 default 10000), `return_with_leftover_noise`(combo: disable/enable).
**Returns:** LATENT

### LoraLoader
**Required:** `model`(MODEL), `clip`(CLIP), `lora_name`(combo: 229 LoRAs — flat list from `/loras/`), `strength_model`(FLOAT -100.0–100.0 default 1.0), `strength_clip`(FLOAT -100.0–100.0 default 1.0).
**Returns:** MODEL, CLIP
**Note:** For LoRA stacks, prefer `Power Lora Loader (rgthree)` — different schema, see below.

### CLIPTextEncode
**Required:** `text`(STRING multiline), `clip`(CLIP).
**Returns:** CONDITIONING

### CheckpointLoaderSimple
**Required:** `ckpt_name`(combo: 10 options — epicrealismXL_pureFix, gonzalomoXLFluxPony_v30FluxDAIO, illustriousRealismBy_v10VAE, intorealismUltra_v10, juggernautXL_ragnarokBy, lustifySDXLNSFW_apexV8, mopMixtureOfPerverts_v71DMD, mopPro_v10, pikonRealism_v2, qwen_image_fp8_hq).
**Returns:** MODEL, CLIP, VAE

### UNETLoader
**Required:** `unet_name`(combo: 17 options — Z-Image-Turbo shards, PornMaster_z-image_Turbo_V0.2_bf16, ...), `weight_dtype`(combo: default/fp8_e4m3fn/fp8_e4m3fn_fast/fp8_e5m2).
**Returns:** MODEL

### VAELoader
**Required:** `vae_name`(combo: 12 options — `wan_2.1_vae`, `LTX23_video_vae_bf16`, `flux2-vae`, `flux_vae`, `qwen_image_vae`, `ae`, ...).
**Returns:** VAE

## Special: Power Lora Loader (rgthree)

Not in the cached list above (worth fetching live), but heavily used in Sven's WAN/LTX workflows. Uses dynamic widget schema:

- Inputs grow as you add LoRAs. Each entry is a dict in `widgets_values`:
  `{"on": bool, "lora": "filename.safetensors", "strength": float, "strengthTwo": float|None}`
- Position 0: empty `{}` placeholder
- Position 1: `{"type": "PowerLoraLoaderHeaderWidget"}`
- Positions 2..N: LoRA entries
- Last position: empty `""` and `{}`

In API format, the keys become numeric: `lora_1`, `lora_2`, etc., each with `{"on", "lora", "strength"}` shape. **Always inspect a working example before constructing from scratch.**

## Workflow

When adding a new node to a workflow:
1. `get_node_schema("NodeClassName")` → see required + optional + types
2. For combo inputs, copy a valid value from the returned list (don't guess filenames)
3. Wire link inputs (`MODEL`, `CLIP`, `IMAGE`, etc.) as `[source_node_id, output_slot]`
4. Set widget values directly: `inputs[name] = value`
5. Run `validate_workflow()` before submitting

If `/object_info/{NodeName}` returns 404 → node isn't loaded. Check ComfyUI startup logs for import errors (e.g. `SvenWaveSpeedNB2` is currently in this state).
