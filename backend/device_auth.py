"""Per-device bearer authentication. JSON registry maps computer_id to SHA-256 token digest.
Never store plaintext tokens in this registry. Standard library only.
"""
import hashlib
import hmac
import json
import re

ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")

def load_registry(path):
    with open(path, "r", encoding="utf-8") as handle:
        registry = json.load(handle)
    if not isinstance(registry, dict) or not registry:
        raise ValueError("registry must be a nonempty object")
    for computer_id, digest in registry.items():
        if not isinstance(computer_id, str) or not ID_RE.fullmatch(computer_id):
            raise ValueError("invalid device identifier")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("invalid SHA-256 digest")
    return registry

def authorized(registry, computer_id, authorization):
    if not isinstance(computer_id, str) or computer_id not in registry:
        return False
    if not isinstance(authorization, str) or not authorization.startswith("Bearer "):
        return False
    token = authorization[7:]
    if len(token) < 32 or len(token) > 512:
        return False
    digest = hashlib.sha256(token.encode("utf-8")).hexdigest()
    return hmac.compare_digest(digest, registry[computer_id])
