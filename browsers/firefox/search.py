#!/usr/bin/env python3
"""browsah - set DuckDuckGo as Firefox's default search engine.

Firefox 128+ stores the default engine (and a tamper-detection hash) in the
profile's search.json.mozlz4, not in a preference. This patches that file:

  * mozlz4 block format (8-byte magic + little-endian size + LZ4 block)
  * defaultEngineId / privateDefaultEngineId -> DuckDuckGo
  * recomputes defaultEngineIdHash / privateDefaultEngineIdHash the exact
    way Firefox does (SHA256 of profile-dir-name + engine id + disclaimer)

usage: search.py <profile-directory>
"""
import base64
import hashlib
import json
import os
import struct
import sys

DISCLAIMER = (
    "By modifying this file, I agree that I am doing so "
    "only within Firefox itself, using official, user-driven search "
    "engine selection processes, and in a way which does not circumvent "
    "user consent. I acknowledge that any attempt to change this file "
    "from outside of Firefox is a malicious act, and will be responded "
    "to accordingly."
)


def decompress_block(data):
    out = bytearray()
    i = 0
    while i < len(data):
        token = data[i]
        i += 1
        lit_len = token >> 4
        if lit_len == 15:
            while True:
                b = data[i]
                i += 1
                lit_len += b
                if b != 255:
                    break
        out += data[i : i + lit_len]
        i += lit_len
        if i >= len(data):
            break
        offset = data[i] | (data[i + 1] << 8)
        i += 2
        match_len = token & 0x0F
        if match_len == 15:
            while True:
                b = data[i]
                i += 1
                match_len += b
                if b != 255:
                    break
        match_len += 4
        start = len(out) - offset
        for j in range(match_len):
            out.append(out[start + j])
    return bytes(out)


def compress_literal_only(data):
    """A valid LZ4 block made of a single literal sequence (no compression,
    but perfectly legal - Firefox decompresses it fine)."""
    n = len(data)
    out = bytearray()
    if n < 15:
        out.append(n << 4)
        out += data
        return bytes(out)
    out.append(0xF0)
    rem = n - 15
    while rem >= 255:
        out.append(255)
        rem -= 255
    out.append(rem)
    out += data
    return bytes(out)


def read_mozlz4(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"mozLz40\0":
        raise ValueError("not a mozlz4 file: %s" % path)
    if data[8:12] == b"\x04\x22\x4d\x18":
        raise ValueError("LZ4 frame format not supported: %s" % path)
    size = struct.unpack("<I", data[8:12])[0]
    return decompress_block(data[12:])[:size]


def write_mozlz4(path, raw):
    block = compress_literal_only(raw)
    with open(path, "wb") as f:
        f.write(b"mozLz40\0")
        f.write(struct.pack("<I", len(raw)))
        f.write(block)


def verification_hash(profile_dir_name, engine_id):
    salt = profile_dir_name + engine_id + DISCLAIMER
    return base64.b64encode(
        hashlib.sha256(salt.encode("utf-8")).digest()
    ).decode()


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 1
    profile = os.path.abspath(sys.argv[1])
    path = os.path.join(profile, "search.json.mozlz4")
    if not os.path.isfile(path):
        print("  - no search.json.mozlz4 yet (run Firefox once); DDG left as-is")
        return 0

    raw = read_mozlz4(path)
    cfg = json.loads(raw.decode("utf-8"))
    meta = cfg.get("metaData", {})

    target = "ddg"
    for eng in cfg.get("engines", []):
        if eng.get("_name") == "DuckDuckGo":
            target = eng.get("id", "ddg")
            break

    prof_name = os.path.basename(profile)
    want_hash = verification_hash(prof_name, target)
    if meta.get("defaultEngineId") == target and meta.get(
        "defaultEngineIdHash"
    ) == want_hash:
        print("  ✓ DuckDuckGo is already the default")
        return 0

    meta["defaultEngineId"] = target
    meta["defaultEngineIdHash"] = want_hash
    meta["privateDefaultEngineId"] = target
    meta["privateDefaultEngineIdHash"] = verification_hash(prof_name, target)
    cfg["metaData"] = meta

    write_mozlz4(path, json.dumps(cfg, separators=(",", ":")).encode("utf-8"))
    print("  ✓ default search -> DuckDuckGo (normal + private)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
