#!/usr/bin/env python3
"""Generate an image through a running ComfyUI instance and record it.

Usage:
    python3 tools/gen.py --prompt "..." --prefix village --seed 42

The script talks to the ComfyUI HTTP API (default http://127.0.0.1:8188),
waits for the job, downloads the PNG into art/raw/ and appends an entry to
art/manifest.json. No third-party dependencies.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = REPO_ROOT / "art" / "raw"
MANIFEST = REPO_ROOT / "art" / "manifest.json"
DEFAULT_CHECKPOINT = "sd_xl_base_1.0.safetensors"
DEFAULT_NEGATIVE = (
    "text, watermark, logo, signature, blurry, low quality, deformed, "
    "extra limbs, photorealistic modern, ui, hud, frame, border"
)


def api(server: str, path: str) -> str:
    return server.rstrip("/") + path


def get_json(url: str, timeout: float = 30.0) -> dict:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.load(response)


def post_json(url: str, payload: dict, timeout: float = 60.0) -> dict:
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.load(response)


def available_checkpoints(server: str) -> list[str]:
    info = get_json(api(server, "/object_info/CheckpointLoaderSimple"))
    required = info["CheckpointLoaderSimple"]["input"]["required"]["ckpt_name"]
    return list(required[0]) if required and required[0] else []


def build_workflow(args: argparse.Namespace, seed: int) -> dict:
    return {
        "1": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {"ckpt_name": args.checkpoint},
        },
        "2": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": args.prompt, "clip": ["1", 1]},
        },
        "3": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": args.negative, "clip": ["1", 1]},
        },
        "4": {
            "class_type": "EmptyLatentImage",
            "inputs": {
                "width": args.width,
                "height": args.height,
                "batch_size": 1,
            },
        },
        "5": {
            "class_type": "KSampler",
            "inputs": {
                "seed": seed,
                "steps": args.steps,
                "cfg": args.cfg,
                "sampler_name": args.sampler,
                "scheduler": args.scheduler,
                "denoise": 1.0,
                "model": ["1", 0],
                "positive": ["2", 0],
                "negative": ["3", 0],
                "latent_image": ["4", 0],
            },
        },
        "6": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["5", 0], "vae": ["1", 2]},
        },
        "7": {
            "class_type": "SaveImage",
            "inputs": {"filename_prefix": args.prefix, "images": ["6", 0]},
        },
    }


def wait_for_result(server: str, prompt_id: str, timeout: float) -> dict:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        history = get_json(api(server, f"/history/{prompt_id}"))
        if prompt_id in history:
            entry = history[prompt_id]
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                raise RuntimeError(
                    "ComfyUI reported an error: "
                    + json.dumps(status.get("messages", []), ensure_ascii=False)
                )
            return entry
        time.sleep(1.0)
    raise TimeoutError(f"ComfyUI did not finish within {timeout:.0f}s")


def download_image(server: str, image: dict) -> bytes:
    query = urllib.parse.urlencode(
        {
            "filename": image["filename"],
            "subfolder": image.get("subfolder", ""),
            "type": image.get("type", "output"),
        }
    )
    with urllib.request.urlopen(api(server, "/view?" + query), timeout=60.0) as response:
        return response.read()


def load_manifest() -> list:
    if not MANIFEST.exists():
        return []
    try:
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []
    return data if isinstance(data, list) else []


def save_manifest(entries: list) -> None:
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    tmp = MANIFEST.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, MANIFEST)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate an asset via ComfyUI")
    parser.add_argument("--prompt", required=True, help="positive prompt (English)")
    parser.add_argument("--negative", default=DEFAULT_NEGATIVE)
    parser.add_argument("--prefix", default="asset", help="filename prefix")
    parser.add_argument("--seed", type=int, default=-1, help="-1 picks a random seed")
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=1024)
    parser.add_argument("--steps", type=int, default=28)
    parser.add_argument("--cfg", type=float, default=7.0)
    parser.add_argument("--sampler", default="dpmpp_2m")
    parser.add_argument("--scheduler", default="karras")
    parser.add_argument("--checkpoint", default=DEFAULT_CHECKPOINT)
    parser.add_argument("--server", default="http://127.0.0.1:8188")
    parser.add_argument("--timeout", type=float, default=600.0)
    parser.add_argument("--license", default="OpenRAIL++-M")
    parser.add_argument("--category", default="concept")
    parser.add_argument("--notes", default="")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    if args.width % 8 or args.height % 8:
        print("error: width/height must be multiples of 8", file=sys.stderr)
        return 2

    try:
        stats = get_json(api(args.server, "/system_stats"), timeout=10.0)
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(f"error: cannot reach ComfyUI at {args.server}: {exc}", file=sys.stderr)
        print("hint: start ComfyUI (port 8188) and retry", file=sys.stderr)
        return 1

    checkpoints = available_checkpoints(args.server)
    if args.checkpoint not in checkpoints:
        print(f"error: checkpoint '{args.checkpoint}' not found", file=sys.stderr)
        print("available: " + ", ".join(checkpoints), file=sys.stderr)
        return 1

    seed = args.seed if args.seed >= 0 else random.randint(0, 2**32 - 1)
    prefix = "".join(ch if ch.isalnum() or ch in "-_" else "_" for ch in args.prefix)
    if not prefix:
        print("error: prefix must contain at least one alphanumeric character", file=sys.stderr)
        return 2

    workflow = build_workflow(args, seed)
    client_id = str(uuid.uuid4())
    try:
        queued = post_json(
            api(args.server, "/prompt"),
            {"prompt": workflow, "client_id": client_id},
        )
        prompt_id = queued["prompt_id"]
        entry = wait_for_result(args.server, prompt_id, args.timeout)
        images = entry.get("outputs", {}).get("7", {}).get("images", [])
        if not images:
            print("error: ComfyUI returned no images", file=sys.stderr)
            return 1
        png = download_image(args.server, images[0])
    except (urllib.error.URLError, TimeoutError, RuntimeError, KeyError) as exc:
        print(f"error: generation failed: {exc}", file=sys.stderr)
        return 1

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    filename = f"{prefix}_{seed}_{stamp}.png"
    target = RAW_DIR / filename
    target.write_bytes(png)

    digest = hashlib.sha256(png).hexdigest()
    record = {
        "file": str(target.relative_to(REPO_ROOT)),
        "category": args.category,
        "status": "raw",
        "prompt": args.prompt,
        "negative": args.negative,
        "seed": seed,
        "steps": args.steps,
        "cfg": args.cfg,
        "width": args.width,
        "height": args.height,
        "checkpoint": args.checkpoint,
        "license": args.license,
        "sha256": digest,
        "bytes": len(png),
        "notes": args.notes,
        "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    entries = load_manifest()
    entries.append(record)
    save_manifest(entries)

    print(json.dumps({"file": record["file"], "seed": seed, "sha256": digest}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
