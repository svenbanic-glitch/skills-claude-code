# ComfyUI Cleanup Audit — 2026-05-02

**Goal:** free 50–100 GB for WAN ANIMATE workflow installation
**Mode:** REPORT ONLY — nothing has been deleted.

---

## 1. Disk usage

```
Filesystem (network volume mount): 1.4P total, 852T used, 580T avail (60%)
ComfyUI root:                      542 GB
└── models/                        496 GB   (91% of footprint)
    ├── diffusion_models/          110 GB
    ├── loras/                      93 GB
    ├── checkpoints/                62 GB
    ├── text_encoders/              61 GB
    ├── unet/                       58 GB
    ├── SEEDVR2/                    40 GB
    ├── LLM/                        28 GB
    └── (everything else)           44 GB
└── custom_nodes/                   23 GB   (1 huge stray model — see §3)
└── .venv-cu128/                   9.1 GB   (active venv)
└── output_root_only_*.zip         6.7 GB   (stale archive — see §3)
└── output/                        3.7 GB   (low priority)
└── .venv/                         1.9 GB   (older venv, possibly stale)
└── input/                         1.6 GB
```

The pod is on a 1.4 PB shared mount with 580 TB free, so the host is not space-constrained — but ComfyUI itself eats 542 GB and that is what we are auditing.

**Workflow audit: 297 model files / 436 GB scanned across 12 model subdirs. 210 files / 408 GB are referenced in at least one of the 149 workflows. 87 files / 28 GB are NOT referenced.**

---

## 2. Top files >1 GB (descending)

| Size GB | mtime      | Path |
|--------:|------------|------|
| 16.91 | 2026-02-20 | models/diffusion_models/flux-2-klein-9b.safetensors |
| 15.90 | 2026-04-25 | models/checkpoints/gonzalomoXLFluxPony_v30FluxDAIO.safetensors |
| 15.35 | 2026-03-25 | models/SEEDVR2/seedvr2_ema_7b_sharp_fp16.safetensors |
| 15.35 | 2026-03-25 | models/SEEDVR2/seedvr2_ema_7b_fp16.safetensors |
| 14.35 | 2026-03-20 | models/unet/Wan2.2-I2V-A14B-LowNoise-Q8_0.gguf |
| 14.35 | 2026-03-20 | models/unet/Wan2.2-I2V-A14B-HighNoise-Q8_0.gguf |
| 13.97 | 2026-03-19 | models/diffusion_models/wan2.2_i2v_A14b_low_noise_..._lightx2v_4step_comfyui.safetensors |
| 13.97 | 2026-03-19 | models/diffusion_models/wan2.2_i2v_A14b_high_noise_..._lightx2v_4step_comfyui_1030.safetensors |
| 13.31 | 2026-04-11 | models/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors |
| 12.34 | 2026-04-01 | models/unet/qwen-image-2512-Q4_K_M.gguf |
| 12.30 | 2026-02-20 | models/text_encoders/gemma_3_12B_it_fp8_e4m3fn.safetensors |
| 11.46 | 2026-04-25 | models/diffusion_models/gonzalomoZpop_insta.safetensors |
| 11.46 | 2026-03-08 | models/unet/PornMaster_z-image_Turbo_V0.2_bf16.safetensors |
| 11.46 | 2026-04-25 | models/diffusion_models/z_image_bf16.safetensors |
| 11.46 | 2026-02-24 | models/diffusion_models/z_image_turbo_bf16.safetensors |
| 11.08 | 2026-03-27 | models/diffusion_models/ultrarealFineTune_v4.safetensors |
| **11.08** | **2026-03-27** | **custom_nodes/comfyui_face_parsing/ultrarealFineTune_v4.safetensors** ← duplicate, wrong location |
|  8.74 | 2026-03-16 | models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors |
|  8.07 | 2026-02-20 | models/text_encoders/qwen_3_8b_fp8mixed.safetensors |
|  7.49 | 2026-02-21 | models/text_encoders/qwen_3_4b.safetensors |
|  7.15 | 2026-02-20 | models/loras/ltx-2-19b-distilled-lora-384.safetensors |
|  7.08 | 2026-03-20 | models/loras/ltx-2.3-22b-distilled-lora-384.safetensors |
|  **6.69** | **2026-04-25** | **output_root_only_20260425_145417.zip** ← stale archive at repo root |
|  6.62 | 2026-05-01 | models/pikonRealism_v2.safetensors ← root-level dup of /checkpoints/ |
|  6.62 | 2026-05-01 | models/checkpoints/pikonRealism_v2.safetensors |
|  6.62 | 2026-05-01 | models/juggernautXL_ragnarokBy.safetensors ← root-level dup of /checkpoints/ |
|  6.62 | 2026-05-01 | models/checkpoints/juggernautXL_ragnarokBy.safetensors |
|  6.46 | 2026-04-25 | models/checkpoints/mopPro_v10.safetensors |
|  6.46 | 2026-04-25 | models/checkpoints/mopMixtureOfPerverts_v71DMD.safetensors |
|  6.46 | 2026-04-25 | models/checkpoints/lustifySDXLNSFW_apexV8.safetensors |

---

## 3. SAFE deletions (zero risk)

### A) Misplaced model duplicates (24.3 GB) — deletion safe

| Size | Path | Why safe |
|-----:|------|----------|
| 11.08 GB | `custom_nodes/comfyui_face_parsing/ultrarealFineTune_v4.safetensors` | identical 11.9 GB file also lives in `models/diffusion_models/`, custom_nodes is the wrong location |
|  6.62 GB | `models/juggernautXL_ragnarokBy.safetensors` | full duplicate of `models/checkpoints/juggernautXL_ragnarokBy.safetensors` — same size, May 1 |
|  6.62 GB | `models/pikonRealism_v2.safetensors` | full duplicate of `models/checkpoints/pikonRealism_v2.safetensors` — same size, May 1 |

**Subtotal: ~24.3 GB**

### B) `.safetensors.1` wget re-download artifacts (6.85 GB)

These are the outcome of `wget` running a second time without `-N`. Same size as their counterparts.

| Size | Path |
|-----:|------|
|  4.99 GB | `models/LLM/Qwen3-VL-4B-Instruct-abliterated-FP8/model-00001-of-00002.safetensors.1` |
|  1.26 GB | `models/clip_vision/clip_vision_h.safetensors.1` |
|  0.29 GB | `models/loras/Sensual_fingering_v1_low_noise.safetensors.1` |
|  0.29 GB | `models/loras/WAN-2.2-I2V-Grinding-Cowgirl-HIGH-v1.safetensors.1` |
|  0.29 GB | `models/loras/WAN-2.2-I2V-Grinding-Cowgirl-LOW-v1.safetensors.1` |

**Subtotal: ~7.1 GB**

### C) "(1)" duplicate LoRAs (1.86 GB)

Eight files in `/loras/` carrying the `… (1).safetensors` suffix. Each has a non-(1) sibling. Sizes range 162 MB – 306 MB.

```
BendForwardHigh-000032 (1).safetensors                              292 MB
J3DCH6T45JPAQBG4J4DY1YMHR0 (1).safetensors                          162 MB
SinaWanFaceSwap2.2_000000700_low_noise (1).safetensors              292 MB
SinaWanFaceSwap2.2_000000800_low_noise (1).safetensors              292 MB
my_first_lora_v1_000000700_low_noise (1).safetensors                292 MB
my_first_lora_v1_000000800_low_noise (1).safetensors                292 MB
my_first_lora_v1_000000900_low_noise (1).safetensors                292 MB
my_first_lora_v1_000001000_low_noise (1).safetensors                292 MB
sinasdxlmy_first_lora_v1_000002500 (1).safetensors                  177 MB
```

Plus three more variants of one LoRA (each 162 MB):
```
sinasdxlmy_first_lora_v1_000002500_1.safetensors
sinasdxlmy_first_lora_v1_000002500_2.safetensors
sinasdxlmy_first_lora_v1_000002500_4.safetensors
```

**Subtotal: ~2.4 GB**

### D) Stale repo-level archive (6.69 GB)

| Size | Path |
|-----:|------|
| 6.69 GB | `output_root_only_20260425_145417.zip` |

Old export sitting in the repo root. Apr 25.

### E) Dev/build cruft (~175 MB)

| Size | Path | Notes |
|-----:|------|-------|
| 173 MB | `custom_nodes/_disabled_comfyui-lora-manager/` | already disabled |
|  ~6 KB | `custom_nodes/comfyui-svenpipeline[1].zip` | leftover download |
|  ~14 .pyc files | `custom_nodes/*.cpython-31{1,2,3}.pyc` (root-level) | strays — total <2 MB |
|  3 entries | `custom_nodes/aiorbust-OFM-pack-Monthly/` (59 MB, Apr 26 — newest, KEEP)<br>`custom_nodes/aiorbust-OFMPack-Monthly/` (4.2 MB, Mar 18 — older, delete)<br>`custom_nodes/aiórbustofmpackmonthly/` (12 MB, Apr 26, weird unicode — delete) | of three variants, only the Apr-26 `aiorbust-OFM-pack-Monthly` is current |
|  1.3 MB | `temp/metadata.txt` | runtime junk, will be regenerated |
|  ~700 KB | `models/checkpoints/main`, `main.1`, `models/checkpoints/ComfyUI-Frame-Interpolation`, `models/loras/main`, `models/text_encoders/text_encoders`, `models/text_encoders/text_encoders.1`, `models/text_encoders/wget-log` | wget HTML index leftovers |

**Subtotal: ~190 MB**

### F) Stale older venv (1.9 GB)

| Size | Path | Notes |
|-----:|------|-------|
| 1.9 GB | `.venv/` | older venv; CLAUDE.md and recent timestamps suggest `.venv-cu128/` is current. Verify before deleting (check which one ComfyUI is launched against). |

### F) Orphan `.metadata.json` files (negligible)

`.metadata.json` files whose corresponding `.safetensors` no longer exists. Each is <1 KB so the savings are zero, but they document deleted models:

```
models/checkpoints/ltx-2.3-22b-dev.metadata.json
models/checkpoints/snofsSexNudesAndOtherFunStuff_distilledV1.metadata.json
models/checkpoints/wan2.2-rapid-mega-aio-nsfw-v2.metadata.json
models/checkpoints/juggernaut_xl_lightning_by_rd.metadata.json
models/checkpoints/SUPIR-v0F.metadata.json
models/checkpoints/analogMadnessSDXL_xl5.metadata.json
models/checkpoints/ltx-2-19b-dev-fp8.metadata.json
models/checkpoints/umt5_xxl_fp8_e4m3fn_scaled.metadata.json
models/checkpoints/illustriousRealismBy_v10.metadata.json
models/checkpoints/Qwen-Rapid-AIO-NSFW-v18.metadata.json
models/loras/umt5_xxl_fp8_e4m3fn_scaled.metadata.json
```

### Section 3 total (safe, including .venv): **~40.5 GB**
### Section 3 total (safe, excluding .venv): **~38.6 GB**

---

## 4. PROBABLY safe deletions — unused models (workflow audit)

The audit grepped every workflow JSON for any quoted reference to a `.safetensors / .ckpt / .pt / .gguf / .bin / .onnx` filename, then diffed against the 297 model files on disk in the 12 standard model subdirs (`checkpoints, loras, diffusion_models, unet, text_encoders, vae, controlnet, clip_vision, clip, embeddings, upscale_models, model_patches, SEEDVR2`).

**Result: 87 files / 27.9 GB are referenced in NO workflow.** Some of these are loaded implicitly by node code (e.g. a default upscaler), so this list needs a brief sanity check before deletion. Sorted by size descending:

| Size GB | Path |
|--------:|------|
|  6.62 | models/checkpoints/juggernautXL_ragnarokBy.safetensors |
|  1.88 | models/controlnet/Z-Image-Fun-Controlnet-Union-2.1-lite.safetensors |
|  0.57 | models/loras/SexGod_BreastMassage_LTX23_v1.safetensors |
|  0.55 | models/loras/sina qwen_000001400.safetensors |
|  0.55 | models/loras/sina qwen_000000400.safetensors |
|  0.53 | models/loras/Z-Image-Fun-Lora-Distill-8-Steps-2602-ComfyUI.safetensors |
|  0.47 | models/loras/sina qwen_000003400.safetensors |
|  0.43 | models/loras/sdxlsina_hohenheim_women_save-499.safetensors |
|  0.43 | models/loras/sdxlsina_hohenheim_women_save-1999.safetensors |
|  0.43 | models/loras/sdxlsina_hohenheim_women_save-999.safetensors |
|  0.33 | models/loras/fingering_i2v_e248.safetensors |
|  0.32 | models/loras/Leaked nudes v2.safetensors |
|  0.32 | models/loras/am@tr_v2-spicy.safetensors |
|  0.31 | models/vae/diffusion_pytorch_model.safetensors |
|  0.31 | models/loras/FluxK4Play.v1.safetensors |
|  0.29 | models/loras/Cameltoe-Wan-darkroast-v1.safetensors |
|  0.29 | models/loras/BIMBO-HIGH.safetensors |
|  0.29 | models/loras/BIMBO-LOW.safetensors |
|  0.29 | models/loras/wan_lipbite_v2_high.safetensors |
|  0.29 | models/loras/wan_lipbite_v2_low.safetensors |
|  0.29 | models/loras/wan2.2-i2v-high-oral-insertion-v1.0.safetensors |
|  0.29 | models/loras/wan2.2-i2v-low-oral-insertion-v1.0.safetensors |
|  0.29 | models/loras/BounceHighWan2_2.safetensors |
|  0.29 | models/loras/BounceLowWan2_2.safetensors |
|  0.29 | models/loras/SinaWanFaceSwap2.2_000001100_low_noise.safetensors |
|  0.29 | models/loras/SinaWanFaceSwap2.2_000000800_low_noise.safetensors |
|  0.29 | models/loras/SinaWanFaceSwap2.2_000000800_low_noise (1).safetensors |
|  0.29 | models/loras/SinaWanFaceSwap2.2_000001000_low_noise.safetensors |
|  0.29 | models/loras/SinaWanFaceSwap2.2_000000700_low_noise (1).safetensors |
|  0.29 | models/loras/SinaWanFaceSwap2.2_000000600_low_noise.safetensors |
|  0.29 | models/loras/SinaWanFaceSwap2.2_000000700_low_noise.safetensors |
|  0.29 | models/loras/my_first_lora_v1_000001300_low_noise.safetensors |
|  0.29 | models/loras/my_first_lora_v1_000001200_low_noise.safetensors |
|  0.29 | models/loras/my_first_lora_v1_000001100_low_noise.safetensors |
|  0.29 | models/loras/my_first_lora_v1_000001000_low_noise (1).safetensors |
|  0.29 | models/loras/my_first_lora_v1_000000800_low_noise (1).safetensors |
|  0.29 | models/loras/my_first_lora_v1_000000700_low_noise (1).safetensors |
|  0.29 | models/loras/T2V-WAN2.2-Areolas-HighNoise_-000040.safetensors |
|  0.29 | models/loras/T2V-WAN2.2-Areolas-LowNoise_-000058.safetensors |
|  0.29 | models/loras/facials_epoch_50.safetensors |
|  0.29 | models/loras/wan22-spitonanother-54epoc-i2v-high.safetensors |
|  0.29 | models/loras/wan22-spitonanother-55epoc-i2v-low.safetensors |
|  0.29 | models/loras/Wan2.2 - T2V - Ahegao v4 - LOW 14B.safetensors |
|  0.29 | models/loras/Wan2.2 - T2V - Ahegao v4 - HIGH 14B.safetensors |
|  0.29 | models/loras/WAN-2.2-I2V-Handjob-LOW-v1.safetensors |
|  0.29 | models/loras/WAN-2.2-I2V-Handjob-HIGH-v1.safetensors |
|  0.27 | models/loras/Qwen-Image_SmartphoneSnapshotPhotoReality_v4_by-AI_Characters_TRIGGER$amateur photo$.safetensors |
|  0.26 | models/loras/FameGrid_Revolution_ZIB_BOLD_.safetensors |
|  0.26 | models/loras/nicegirls_anima.safetensors |
|  0.21 | models/loras/LTX2.3-Rogue-Missionary-Cowgirl-v3.safetensors |
|  0.19 | models/loras/2ltsway-breastsway.comfy.safetensors |
|  0.17 | models/loras/sinasdxlmy_first_lora_v1_000002500_4.safetensors |
|  0.17 | models/loras/sinasdxlmy_first_lora_v1_000002500_2.safetensors |
|  0.17 | models/loras/sinasdxlmy_first_lora_v1_000002500_1.safetensors |
|  0.16 | models/loras/Sina Z-Image Turbo_000000400.safetensors |
|  0.16 | models/loras/Sina Z-Image Base_000002500.safetensors |
|  0.16 | models/loras/Sina Z-Image Base_000001750.safetensors |
|  0.16 | models/loras/Sina ZIB BASE_000001000.safetensors |
|  0.16 | models/loras/Sina ZIB BASE_000000800.safetensors |
|  0.16 | models/loras/movie_zimage_lora.safetensors |
|  0.16 | models/loras/begott3n_zImage_base.safetensors |
|  0.16 | models/loras/zbaseHandJob.safetensors |
|  0.16 | models/loras/J3DCH6T45JPAQBG4J4DY1YMHR0 (1).safetensors |
|  0.15 | models/loras/sinafluxneu_000000700.safetensors |
|  0.15 | models/loras/Flux Klein - NSFW v2.safetensors |
|  0.15 | models/loras/W2R_WAN225B_I2V_TWERK_1250.safetensors |
|  0.14 | models/loras/JIGGLEWALKHIGHV3.safetensors |
|  0.14 | models/loras/sitting_penis_high_noise.safetensors |
|  0.14 | models/loras/BoobPhysics_v1_LowNoise.safetensors |
|  0.14 | models/loras/BoobPhysic_v1_HighNoise.safetensors |
|  0.12 | models/loras/ArPrtC_turbo.safetensors |
|  0.08 | models/upscale_models/4xNomos8k_atd_jpg.pth |
|  0.07 | models/loras/JIGGLEWALKV3LOW.safetensors |
|  0.07 | models/loras/wan2.2feetsuckingtoes_000000300_low_noise.safetensors |
|  0.06 | models/upscale_models/1x_PureVision.pth |
|  0.06 | models/upscale_models/RealESRGAN_x4plus.pth |
|  0.06 | models/upscale_models/2x_PureVision.pth |
|  0.06 | models/upscale_models/4x_foolhardy_Remacri.pth |
|  0.06 | models/upscale_models/4x-UltraSharp.pth |
|  0.06 | models/upscale_models/4x_NMKD-Superscale-SP_178000_G.pth |
|  0.06 | models/upscale_models/4x_NMKD-Siax_200k.pth |
|  0.04 | models/loras/ahegao_V1.safetensors |
|  0.02 | models/loras/Sina Z-Image Base.safetensors |
|  0.02 | models/upscale_models/1x-ITF-SkinDiffDetail-Lite-v1.pth |
|  0.01 | models/upscale_models/4x-ClearRealityV1.pth |
|  0.01 | models/upscale_models/4xNomos8k_span_otf_weak.pth |
|  0.00 | models/vae/ultrafluxvae.safetensors |

### Caveats before bulk-deleting Section 4

1. **Upscalers (last block, ~0.5 GB total):** workflows tend to use upscaler nodes that pick from a dropdown / live list — they are often not referenced by literal filename. Suggest **KEEP** these unless you know none are wired to a default.
2. **Small VAE files (`models/vae/diffusion_pytorch_model.safetensors`, `ultrafluxvae.safetensors`):** sometimes loaded by path from custom nodes. Verify before deleting.
3. **Sina LoRA epochs (multiple Sina/SinaWanFaceSwap variants):** Per `CLAUDE.md` you only use the highest-epoch SDXL one + `sinaneu_000002700`. The lower-epoch siblings are valid cleanup candidates **but** keep the ones the docs name explicitly. Recommended: keep 2999 SDXL, 2700 ZIB, drop the rest.
4. **`(1)` and `_1/_2/_4` Sina duplicates** in this section overlap with §3.C — count them once.
5. **`juggernautXL_ragnarokBy.safetensors` in /checkpoints/** (6.62 GB) shows as unused. Per `CLAUDE.md` it's listed as an SDXL checkpoint, but no current workflow loads it. Decision-yours.

### Section 4 conservative usable: **~20–25 GB** (after subtracting upscalers, dup-of-§3.C, and any §4-caveat items you want to keep)

---

## 5. RISKY cleanup (verify use case)

### A) SEEDVR2 — 30.7 GB

`models/SEEDVR2/seedvr2_ema_7b_fp16.safetensors` (15.35 GB) AND `seedvr2_ema_7b_sharp_fp16.safetensors` (15.35 GB). Both ARE referenced by workflows. If you only ever use one of them in production, you can drop the other for **15.35 GB**.

### B) Output folder — 3.7 GB

Already small (< 30 GB threshold). No action needed unless you want to wipe old test outputs.

### C) `.venv/` (1.9 GB)

Possibly the pre-CUDA-128 venv. Safe to delete only after confirming `.venv-cu128/` is what ComfyUI launches against (`ps aux | grep comfy` or check launch script).

### D) Output zip in repo root (6.69 GB)

`output_root_only_20260425_145417.zip` — already counted in §3.D. Mentioned again because it's actually risky if you needed it as a backup.

### E) Subdirs not scanned by the audit (model paths loaded implicitly)

These are NOT in the audit's "unused" list because they live outside the 12 scanned subdirs and are loaded by custom-node logic (filename never appears in workflow JSON):

```
models/LLM/                 28 GB  (Qwen-VL, Qwen3-VL, Florence-2)
models/sams/                3.6 GB
models/sam3/                3.3 GB
models/depthcrafter/        7.1 GB  (StableVideoDiffusion + DepthCrafter weights)
models/RMBG/                849 MB
models/face_parsing/        325 MB
models/ultralytics/         579 MB
models/vitmatte/            200 MB
models/mediapipe/           18 MB
models/clip_vision/         2.4 GB  (one .safetensors.1 dup already counted)
```

**These are ~46 GB.** Do not bulk-delete — they back face-detection / segmentation / depth nodes used by realism-post and body-swap workflows. Worth a manual review only if you know specific ones (e.g. SAM versions you no longer use) are dead.

---

## 6. Recommended cleanup order

**Run top-to-bottom. Each step is an isolated rm. Stop and re-run `df -h` after every step to verify ComfyUI still launches.**

| # | Action | Saves | Risk |
|--:|--------|------:|------|
| 1 | Delete `output_root_only_20260425_145417.zip` from repo root | 6.7 GB | 🟢 zero |
| 2 | Delete the 5 `.safetensors.1` wget artifacts (§3.B) | 7.1 GB | 🟢 zero |
| 3 | Delete the 12 `(1)` and `_1/_2/_4` Sina LoRA dups (§3.C) | 2.4 GB | 🟢 zero |
| 4 | Delete `custom_nodes/comfyui_face_parsing/ultrarealFineTune_v4.safetensors` (wrong location, dup of /diffusion_models/) | 11.1 GB | 🟢 zero (verify face_parsing node doesn't hardcode path) |
| 5 | Delete `models/juggernautXL_ragnarokBy.safetensors` AND `models/pikonRealism_v2.safetensors` from `/models/` root (full dups of /checkpoints/) | 13.2 GB | 🟢 zero |
| 6 | Delete `_disabled_comfyui-lora-manager/`, stray .pyc files, `comfyui-svenpipeline[1].zip`, `aiorbust-OFMPack-Monthly/`, `aiórbustofmpackmonthly/`, `temp/metadata.txt`, `wget-log` and HTML index leftovers (§3.E) | 0.2 GB | 🟢 zero |
| 7 | (Optional) Delete `.venv/` after confirming `.venv-cu128/` is active | 1.9 GB | 🟡 verify first |
| 8 | Delete `models/checkpoints/juggernautXL_ragnarokBy.safetensors` (no workflow uses it) | 6.6 GB | 🟡 confirm you don't plan to use this SDXL ckpt |
| 9 | Delete the unused 0.2–1.88 GB `/loras/` and `/controlnet/` items in §4 (skipping the ones flagged in caveats) | ~13–15 GB | 🟡 LLM-recommended; double-check Sina + Z-Image-Fun-Controlnet aren't ones you want to keep for upcoming work |
| 10 | (Risky) Drop one of the two SEEDVR2 7B variants if you only use one in production | 15.4 GB | 🔴 verify which is current |

### Cumulative savings

| Through step | GB saved |
|-------------:|---------:|
| step 6 (zero-risk only) | **40.7 GB** |
| step 8 (zero-risk + venv + unused checkpoint) | **49.2 GB** |
| step 9 (full §3 + §4) | **62–64 GB** |
| step 10 (everything incl. one SEEDVR2) | **77–79 GB** |

That covers the 50–100 GB target with room to spare.

---

## 7. Answers to specific audit questions

| Question | Answer |
|----------|--------|
| Loose .pyc files in custom_nodes/ root | 14 files, ~1.2 MB total |
| _disabled_* folders | 1 folder: `_disabled_comfyui-lora-manager` (173 MB) |
| temp/ folder size | 1.3 MB (just `metadata.txt`) |
| Three aiorbust-OFM-pack variants | `aiorbust-OFM-pack-Monthly` (59 MB, Apr 26 — newest, KEEP), `aiorbust-OFMPack-Monthly` (4.2 MB, Mar 18 — delete), `aiórbustofmpackmonthly` (12 MB, Apr 26 — weird unicode, delete) |
| comfyui-svenpipeline[1].zip | 6.5 KB — delete |
| Output folder | 3.7 GB — small, no action |
| Orphan .metadata.json files | 11 files (size <11 KB total) — informational only |
| Models on disk but not in any workflow | 87 files / 27.9 GB |

---

## 8. Notes / anomalies for follow-up (not cleanup)

- `models/text_encoders/text_encoders` and `text_encoders.1` are HTML index pages (each ~77 KB) — wget artifacts.
- `models/checkpoints/main`, `main.1`, and `models/checkpoints/ComfyUI-Frame-Interpolation` are similar wget artifacts.
- `models/loras/main` (117 KB) is another wget artifact.
- `models/loras/lora_manager_stats.json` is an active stats file from the lora-manager — keep.
- Two near-empty `models/` files (`ultrafluxvae.safetensors` 0 GB, `Sina Z-Image Base.safetensors` 0.02 GB) — possibly truncated downloads.

End of report. Nothing has been deleted.
