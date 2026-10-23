"""카드 JSON 스트림에서 완성된 요약만 조기에 추출해요."""

import json


def completed_summary(buffer: str) -> str | None:
    """최상위 quality와 summary 값이 모두 완성된 경우에만 요약을 반환해요."""
    start = buffer.find("{")
    if start < 0:
        return None
    decoder = json.JSONDecoder()
    position = start + 1
    quality: object = None
    while position < len(buffer):
        position = _skip_space_and_comma(buffer, position)
        if position >= len(buffer) or buffer[position] == "}":
            return None
        try:
            key, position = decoder.raw_decode(buffer, position)
        except json.JSONDecodeError:
            return None
        if not isinstance(key, str):
            return None
        position = _skip_space_and_comma(buffer, position)
        if position >= len(buffer) or buffer[position] != ":":
            return None
        position = _skip_space_and_comma(buffer, position + 1)
        try:
            value, position = decoder.raw_decode(buffer, position)
        except json.JSONDecodeError:
            return None
        if key == "quality":
            quality = value
        elif key == "summary":
            if isinstance(quality, dict) and quality.get("is_sufficient") is True:
                return value.strip() if isinstance(value, str) and value.strip() else None
            return None
    return None


def _skip_space_and_comma(buffer: str, position: int) -> int:
    while position < len(buffer) and buffer[position] in " \t\r\n,":
        position += 1
    return position
