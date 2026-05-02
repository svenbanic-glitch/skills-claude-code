---
name: workflow_factory
description: Read, analyze, and modify existing ComfyUI workflow JSONs. Use as base for any "modify my workflow X" or "build a variant of Y" request.
---

# workflow_factory

Toolkit for reading, analyzing, and modifying existing ComfyUI workflow JSONs. Always start from an existing workflow rather than reinventing — Sven's workflows in `/workspace/runpod-slim/ComfyUI/user/default/workflows/` are battle-tested.

## When to use
- User says "modify my workflow X", "build a variant of Y", "swap LoRA in workflow Z"
- User pastes a workflow JSON and asks to change parameters
- Building a new workflow that's similar to an existing one
- Debugging why a submitted workflow returns errors

## Two formats — detect first

ComfyUI uses **two different JSON formats**. Always detect before parsing:

| Format | Top-level keys | Source | Use case |
|---|---|---|---|
| **Graph (UI)** | `nodes`, `links`, `groups`, `config`, `extra` | Saved from UI via "Save" | Editing in UI |
| **API (prompt)** | Numeric keys (`"1": {...}, "2": {...}`) with `class_type`, `inputs` | Saved via "Save (API Format)" or `/prompt` endpoint | Submitting to `/prompt` API |

```python
import json

def detect_format(wf: dict) -> str:
    if "nodes" in wf and "links" in wf:
        return "graph"
    if all(isinstance(k, str) and k.isdigit() for k in wf.keys()):
        return "api"
    if any(isinstance(v, dict) and "class_type" in v for v in wf.values()):
        return "api"
    return "unknown"
```

**Rule:** `/prompt` API only accepts API format. If user pastes a Graph format and wants to submit, convert first.

## Graph → API conversion

```python
def graph_to_api(graph: dict) -> dict:
    """Convert UI-saved graph to API-submittable prompt dict."""
    api = {}
    nodes = {n["id"]: n for n in graph["nodes"]}
    # Build link map: link_id -> (from_node_id, from_slot)
    links = {l[0]: (l[1], l[2]) for l in graph.get("links", [])}

    for nid, node in nodes.items():
        if node.get("mode") == 4:  # bypassed
            continue
        if node["type"] in ("Reroute", "PrimitiveNode", "Note"):
            continue

        inputs = {}
        # widget values — the order matches widgets_values, but mapping
        # requires the node's INPUT_TYPES schema. For exact mapping use
        # /object_info/{class_type} to know which inputs are widgets vs links.
        widget_vals = node.get("widgets_values", []) or []

        for inp in node.get("inputs", []) or []:
            link_id = inp.get("link")
            if link_id is not None and link_id in links:
                src_id, src_slot = links[link_id]
                inputs[inp["name"]] = [str(src_id), src_slot]

        api[str(nid)] = {
            "class_type": node["type"],
            "inputs": inputs,
            # widget values still need to be merged in by name — see object_info_resolver skill
        }
    return api
```

For a full conversion that handles widget→input name mapping correctly, query `/object_info/{class_type}` per node — see `object_info_resolver` skill.

## Find nodes by class_type

```python
def find_nodes(wf: dict, class_type: str) -> list[tuple[str, dict]]:
    """Return [(node_id, node_dict), ...] for all matches."""
    fmt = detect_format(wf)
    if fmt == "api":
        return [(k, v) for k, v in wf.items() if v.get("class_type") == class_type]
    if fmt == "graph":
        return [(str(n["id"]), n) for n in wf["nodes"] if n.get("type") == class_type]
    return []

# Common targets
ksamplers = find_nodes(wf, "KSampler") + find_nodes(wf, "KSamplerAdvanced")
loras     = find_nodes(wf, "LoraLoader") + find_nodes(wf, "LoraLoaderModelOnly")
prompts   = find_nodes(wf, "CLIPTextEncode")
saves     = find_nodes(wf, "SaveImage") + find_nodes(wf, "VHS_VideoCombine")
checkpts  = find_nodes(wf, "CheckpointLoaderSimple") + find_nodes(wf, "UNETLoader")
```

## Locate KSampler settings

In API format, KSampler `inputs` always include: `seed`, `steps`, `cfg`, `sampler_name`, `scheduler`, `denoise`. Plus `model`, `positive`, `negative`, `latent_image` as link references.

```python
for nid, node in find_nodes(wf, "KSampler"):
    inp = node["inputs"]
    print(f"Node {nid}: steps={inp.get('steps')} cfg={inp.get('cfg')} "
          f"sampler={inp.get('sampler_name')} scheduler={inp.get('scheduler')} "
          f"denoise={inp.get('denoise')} seed={inp.get('seed')}")
```

## Identify LoRA loaders

```python
for nid, node in find_nodes(wf, "LoraLoader"):
    inp = node["inputs"]
    print(f"Node {nid}: lora={inp.get('lora_name')} "
          f"strength_model={inp.get('strength_model')} "
          f"strength_clip={inp.get('strength_clip')}")
# Also check chained LoRA stacks: "Power Lora Loader (rgthree)", "LoraStacker"
```

Reminder: LoRAs in this pod are **flat in `/models/loras/`** — never use subfolder paths.

## Find prompt nodes

```python
for nid, node in find_nodes(wf, "CLIPTextEncode"):
    text = node["inputs"].get("text", "")
    # Determine if positive or negative by tracing where its output feeds.
    # Quick heuristic: look at KSampler's positive/negative link → match node id.
    print(f"Node {nid}: {text[:120]!r}")
```

## Rename Save nodes (output prefix)

```python
def set_save_prefix(wf: dict, prefix: str):
    for cls in ("SaveImage", "Image Save", "VHS_VideoCombine"):
        for nid, node in find_nodes(wf, cls):
            if cls == "SaveImage":
                node["inputs"]["filename_prefix"] = prefix
            elif cls == "VHS_VideoCombine":
                node["inputs"]["filename_prefix"] = prefix
            elif cls == "Image Save":
                node["inputs"]["filename"] = prefix

# Sven's convention: YYYYMMDD_descriptive-slug
import datetime
set_save_prefix(wf, f"{datetime.date.today():%Y%m%d}_sina-zimage-batch1")
```

## Parameter swap helper

```python
def swap(wf: dict, class_type: str, field: str, new_value, node_id: str | None = None):
    """Swap `field` in `inputs` of all nodes matching class_type (or single node_id)."""
    for nid, node in find_nodes(wf, class_type):
        if node_id and nid != node_id:
            continue
        node["inputs"][field] = new_value

# Examples
swap(wf, "KSampler", "seed", 42)
swap(wf, "LoraLoader", "strength_model", 0.85)
swap(wf, "CheckpointLoaderSimple", "ckpt_name", "epicrealismXL_pureFix.safetensors")
```

## Submit to /prompt endpoint

```python
import urllib.request, json, time, uuid

def submit(api_workflow: dict, client_id: str | None = None) -> str:
    payload = {"prompt": api_workflow, "client_id": client_id or str(uuid.uuid4())}
    req = urllib.request.Request(
        "http://localhost:8188/prompt",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as r:
        resp = json.load(r)
    return resp["prompt_id"]

def poll(prompt_id: str, interval=2, timeout=900):
    deadline = time.time() + timeout
    while time.time() < deadline:
        with urllib.request.urlopen(f"http://localhost:8188/history/{prompt_id}") as r:
            hist = json.load(r)
        if prompt_id in hist:
            return hist[prompt_id]
        time.sleep(interval)
    raise TimeoutError(prompt_id)
```

## Best practice: ALWAYS summarize first, modify second

When asked to "modify workflow X":

1. **Load + detect format**
2. **Inventory** — print every node relevant to the user's request:
   - Checkpoints / UNet / VAE loaders → which model files
   - LoRA loaders → which loras + strengths
   - KSamplers → steps/cfg/sampler/scheduler/denoise/seed
   - CLIPTextEncode → positive + negative prompts (truncate to 120 chars)
   - Save/Output nodes → filename prefixes
   - Image/Video loaders → input paths
3. **Confirm scope** with user if anything's ambiguous (or pick a sensible default and state what you did)
4. **Apply changes**
5. **Validate** — re-run `find_nodes` after to confirm changes landed

This prevents the most common failure mode: editing the wrong node when the workflow has multiple KSamplers / LoRA stacks / Save nodes.

## Common pitfalls
- **Multiple KSamplers in sectioned workflows** (CLSNPNSFW_SECTIONED, CLSNP_LTX23_SECTIONED) — there are 12 KSamplers, one per section. Modifying "the" KSampler means modifying all 12.
- **High/Low noise WAN 2.2 pairs** — most WAN LoRAs come as `_HIGH` + `_LOW` pairs and BOTH must be loaded with matching strengths.
- **Power Lora Loader (rgthree)** — has a different schema than `LoraLoader`. LoRAs live as `lora_1`, `lora_2`, ... entries each with `{"on": bool, "lora": str, "strength": float}`.
- **Bypassed nodes** (`mode: 4` in graph format) — don't include in API output, but their downstream links break. Trace through carefully.
- **Reroute nodes** — pure pass-through, must be resolved during graph→API conversion.
- **Widget vs link inputs** — same parameter (e.g. `seed`) can be either a widget value or a linked input. The API format handles both as `inputs[name]`, but value type differs (`int` vs `[node_id, slot]`).
