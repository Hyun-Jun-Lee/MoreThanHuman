"""표시 문구를 제외한 지식의 결정적 식별자."""

import hashlib
import json
import unicodedata


def normalized_text(value: str) -> str:
    return " ".join(unicodedata.normalize("NFC", value).split())


def stable_json(value) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def canonical_identity(identity: dict) -> dict:
    def normalize(value):
        if isinstance(value, str):
            return normalized_text(value)
        if isinstance(value, dict):
            return {
                key: normalize(item) for key, item in value.items() if item is not None
            }
        if isinstance(value, list):
            return [normalize(item) for item in value]
        return value

    result = normalize(identity)
    result["entries"] = sorted(result["entries"], key=stable_json)
    return result


def knowledge_key(identity: dict) -> str:
    return hashlib.sha256(
        stable_json(canonical_identity(identity)).encode("utf-8")
    ).hexdigest()
