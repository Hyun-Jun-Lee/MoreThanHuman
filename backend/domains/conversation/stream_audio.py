"""완성 문장별 TTS를 NDJSON 이벤트로 변환해요."""

import json
import re


def completed_sentences(text: str, *, max_chars: int = 400) -> list[str]:
    """저장된 짧은 질문을 문장 경계로 분리하고 TTS 입력 크기를 제한해요."""
    normalized = " ".join(text.split())
    if not normalized:
        return []
    # 첫 버전의 입력은 사전 생성된 짧은 질문이에요. 호칭·영문 이니셜 뒤에서는 자르지 않아요.
    abbreviations = {"dr.", "mr.", "mrs.", "ms.", "prof.", "st.", "vs.", "e.g.", "i.e."}
    parts: list[str] = []
    start = 0
    for boundary in re.finditer(r"(?<=[.!?。！？])\s+", normalized):
        candidate = normalized[start:boundary.start()]
        last_word = candidate.rsplit(" ", 1)[-1].lower()
        if last_word in abbreviations or re.fullmatch(r"(?:[a-z]\.){2,}", last_word):
            continue
        parts.append(candidate)
        start = boundary.end()
    parts.append(normalized[start:])
    sentences: list[str] = []
    for part in parts:
        words = part.split(" ")
        current = ""
        for word in words:
            candidate = f"{current} {word}" if current else word
            if len(candidate) > max_chars and current:
                sentences.append(current)
                current = word
            else:
                current = candidate
        if current:
            sentences.append(current)
    return sentences


def event_line(event: str, seq: int, turn_id: str, attempt_id: str, **fields: object) -> bytes:
    payload = {"event": event, "seq": seq, "turn_id": turn_id, "attempt_id": attempt_id, **fields}
    return (json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")
