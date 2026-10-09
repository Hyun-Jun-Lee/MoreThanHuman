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


class SentenceBuffer:
    """LLM delta에서 완성된 문장만 꺼내고 마지막 꼬리는 종료 때 돌려줘요."""

    def __init__(self, max_chars: int = 400):
        self.pending = ""
        self.max_chars = max_chars

    def feed(self, delta: str) -> list[str]:
        self.pending += delta
        ready: list[str] = []
        while self.pending:
            boundary = None
            for match in re.finditer(r"(?<=[.!?。！？])\s+", self.pending):
                candidate = self.pending[:match.start()].strip()
                last_word = candidate.rsplit(" ", 1)[-1].lower()
                if last_word not in {"dr.", "mr.", "mrs.", "ms.", "prof.", "st.", "vs.", "e.g.", "i.e."}:
                    boundary = match
                    break
            if boundary is not None:
                candidate = self.pending[:boundary.start()].strip()
                ready.extend(completed_sentences(candidate, max_chars=self.max_chars))
                self.pending = self.pending[boundary.end():]
                continue
            if len(self.pending) <= self.max_chars:
                break
            cut = self.pending.rfind(" ", 0, self.max_chars + 1)
            if cut <= 0:
                cut = self.max_chars
            ready.append(self.pending[:cut].strip())
            self.pending = self.pending[cut:].lstrip()
        return [sentence for sentence in ready if sentence]

    def finish(self) -> list[str]:
        tail = completed_sentences(self.pending, max_chars=self.max_chars)
        self.pending = ""
        return tail
