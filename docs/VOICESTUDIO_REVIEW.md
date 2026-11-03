# VoiceStudio의 GPU 없는 STT·TTS 활용 검토

> 검토일: 2026-09-16 · 상태: 검토 제안, 구현·배포 없음

## 결론

GPU 서버가 없어도 CPU 엔진으로 음성 처리를 할 수 있어요. 다만 현재 서비스의 실시간 대화를 VoiceStudio 기본 설정으로 전면 대체하는 것은 권하지 않아요. STT는 기존 API를 유지하고, CPU TTS를 별도 프로세스로 시험한 뒤 성능·품질·비용이 유리한 경우에만 전환하는 안을 권해요. VoiceStudio 자체는 엔진 비교·음색 평가·고정 학습 콘텐츠 사전 제작에 활용할 수 있어요.

이는 공식 문서와 현재 서비스 코드에 근거한 판단이에요. 모델 설치·실행·청취·부하 시험은 하지 않았으며 서버 CPU·RAM·아키텍처·동시 사용자 수·실제 음성 청구액은 확인하지 않았어요. 외부 자료는 확인 당시 main 문서 기준이므로 실제 실험에서는 릴리스와 모델 revision을 고정해야 해요.

## 현재 서비스와의 차이

- `backend/config.py` 기본값은 STT `openrouter / openai/gpt-4o-mini-transcribe`, TTS `openrouter / microsoft/mai-voice-2-flash`예요. 운영 환경변수의 실제 값은 이번에 확인하지 않았어요.
- `backend/domains/voice/service.py`의 `_create_provider()`는 STT와 TTS 공급자가 다르면 오류를 내요. 환경변수 두 개가 있다고 해서 서로 다른 공급자를 조합할 수 있는 상태는 아니에요.
- `openai_provider.py`와 `openrouter_provider.py`에는 호출 URL이 고정돼 있어요. OpenAI 호환 서버라도 설정만 바꿔 연결할 수는 없어요.
- 현재는 녹음 업로드 → STT 완료 → LLM 전체 응답 → TTS 전체 오디오 → Base64 JSON → 앱 재생이에요. VoiceStudio로 교체하는 것만으로 첫 음성 스트리밍이 생기지 않아요.
- OpenAI direct는 선택 가능한 대안이며, 코드상 장애 시 자동 공급자 전환은 구현돼 있지 않아요.
- 관련 기준: [API 계약](DSL.md), [현재 계측](VOICE_LATENCY.md), [미구현 스트리밍 제안](VOICE_STREAMING.md).

## CPU 후보

| 영역 | 후보 | 확인된 특성 | 이 서비스에 대한 판단 |
|------|------|-------------|------------------------|
| STT | Faster-Whisper | CPU int8 지원, VoiceStudio 기본 모델은 large-v3 | 다국어 small/base부터 기존 API와 비교할 후보예요. 기본 large 모델을 그대로 CPU에 올리는 안은 우선순위가 낮아요. |
| TTS | Supertonic-3 | CPU ONNX, 영어·한국어 포함 31개 언어, 고정 음색 | 양방향 언어 학습을 유지할 첫 실험 후보예요. OpenRAIL-M 모델 조건을 검토해야 해요. |
| TTS | KittenTTS | 경량 CPU 실행, 영어 전용, 고정 음색 | 영어 연습 문장·역할극 음성의 비교 후보예요. 한국어 경로 전체를 대체할 수는 없어요. |
| TTS | 기본 OmniVoice | CPU 경로도 있지만 사전학습 가중치 CC-BY-NC | 상업 서비스의 기본 대체 모델로 채택하지 않는 안을 권해요. 별도 권리 확보 없이 상업 이용 가능하다고 전제하면 안 돼요. |

근거: [Faster-Whisper 통합](https://github.com/debpalash/VoiceStudio/blob/main/docs/engines/faster-whisper.md), [Supertonic-3 통합](https://github.com/debpalash/VoiceStudio/blob/main/docs/engines/supertonic3.md), [Supertonic 모델 카드](https://huggingface.co/Supertone/supertonic-3), [KittenTTS 통합](https://github.com/debpalash/VoiceStudio/blob/main/docs/engines/kittentts.md), [KittenTTS upstream](https://github.com/KittenML/KittenTTS), [OmniVoice 모델 카드](https://huggingface.co/k2-fsa/OmniVoice).

CPU 실행 가능 여부와 회화 서비스의 지연·동시 처리 성능은 별개예요. VoiceStudio의 [벤치마크 표](https://github.com/debpalash/VoiceStudio/blob/main/docs/benchmarks.md)는 확인 시점에 검증된 결과 행이 없어요. [Faster-Whisper upstream](https://github.com/SYSTRAN/faster-whisper)은 i7-12700K 8스레드에서 13분 오디오를 small/int8로 1분 42초에 전사한 수치를 공개하지만, 이를 짧은 학습자 발화나 공유 VPS의 지연으로 환산해서는 안 돼요.

## 활용 경로와 권장 순서

1. **평가·제작 도구:** 개발 환경에서 엔진별 샘플을 비교하고, 라이선스가 적합한 엔진으로 고정 예문·역할극 안내·스낵 예문 오디오를 미리 만들어요. 사람의 청취 검수 후 저장소/CDN에 올리는 방식은 요청 시 추론을 피할 수 있어요. 현재 스낵에 음성 자산을 연결하려면 별도 데이터/API/UI 작업이 필요해요.
2. **CPU TTS만 실험:** 기존 클라우드 STT → 기존 LLM → 별도 CPU TTS → 기존 앱 응답 구조로 비교해요. 처음에는 VoiceStudio API 어댑터도 가능하지만, 운영 범위가 STT/TTS뿐이면 upstream 엔진을 독립 서비스로 직접 감싸는 구성이 더 작아요.
3. **CPU STT 추가 검토:** 한국어 화자의 영어, 문법 오류, 머뭇거림, 작은 소리와 소음에서 전사 정확도를 검증한 후 판단해요. STT가 학습자의 잘못된 문장을 올바른 문장으로 보정하면 문법 피드백의 입력 자체가 달라질 수 있어요. dictation의 LLM refinement 기능은 이 경로에서 사용하지 않는 안을 권해요.
4. **속도가 목적이라면 별도 스트리밍 작업:** 기존 계측에서 병목을 확인한 뒤 문장별 생성·재생을 검토해요. 로컬 추론은 네트워크 왕복을 줄여도 CPU 계산·대기열 때문에 전체 대기 시간이 증가할 수 있어요.

VoiceStudio의 [speech platform](https://github.com/debpalash/VoiceStudio/blob/main/docs/speech-platform.md)은 파일 STT용 `POST /v1/audio/transcriptions`와 실시간 STT WebSocket을 문서화해요. TTS는 [성능 문서](https://github.com/debpalash/VoiceStudio/blob/main/docs/performance.md)에 `/ws/tts`가 등장해요. 선택 릴리스의 TTS 요청 스키마·오디오 framing·엔진별 지원은 구현 전 별도 계약 시험이 필요해요. 현재 OpenAI provider에 URL만 교체하면 완전히 호환된다고 판단하지 않아요.

## 통합 시 필요한 변경

- STT/TTS 공급자 생성과 주입을 분리하고, 각각의 설정·오류 처리를 유지해요.
- 전사 결과는 기존 `VoiceTranscriptionResult`, 합성 결과는 `VoiceSynthesisResult`로 변환하는 어댑터를 둬요.
- 대화에 저장된 target language를 TTS까지 전달해요. 현재 `synthesize_speech(text)`에는 언어 인자가 없어요. 영어 전용 엔진으로 한국어를 보내지 않도록 선택 규칙이 필요해요.
- CPU 추론은 FastAPI 요청 이벤트 루프 밖의 별도 프로세스/컨테이너로 격리하고 모델을 상주시켜요. 같은 서버라면 CPU·RAM 제한으로 API와 DB의 자원 경쟁을 제어해요.
- 대기열 상한·시간 제한을 두고, TTS 실패 시 기존 `audio_error` 정책을 유지해요. 클라우드 자동 fallback은 별도 구현 사항이며, 대화 전체 재시도로 중복 메시지를 만들면 안 돼요.
- 반환 오디오의 WAV/MP3, MIME, 샘플레이트, 크기 제한과 Flutter 재생을 검증해요. 기존 5MB 출력 제한은 비압축 오디오에서 더 쉽게 도달할 수 있어요.
- VoiceStudio를 서버로 사용하면 내부망과 인증을 적용하고 관리·모델 설치 API를 사용자 앱에 직접 노출하지 않아요.
- 구현한다면 환경 설정 3개 표면과 API·실행 관련 문서를 AGENTS.md 등록부에 맞춰 갱신해요. 이번 검토는 활성 계약을 바꾸지 않아요.

## 배포·라이선스 고려

VoiceStudio는 [CPU Docker 실행](https://github.com/debpalash/VoiceStudio/blob/main/docs/install/docker.md)을 제공해요. 공개 이미지는 문서상 linux/amd64 전용이므로 ARM 서버라면 그대로 적용할 수 없어요. Apple Silicon의 가속은 네이티브 실행의 선택지이며 Linux Docker에서 Mac GPU를 사용할 수 있다는 뜻은 아니에요.

[공식 라이선스 고지](https://github.com/debpalash/VoiceStudio/blob/main/LICENSE-NOTICE.md)에 따르면 앱은 AGPL-3.0이고, 수정본을 네트워크로 제공할 때 해당 소스 제공 의무가 명시돼 있어요. 서비스 전체의 공개 범위는 결합·배포 구조를 따져야 하며, HTTP로 분리했다는 이유만으로 의무가 모두 없어지는 것은 아니에요. VoiceStudio 상업 라이선스도 외부 모델 가중치의 권리를 대신하지 않아요. upstream 엔진 직접 사용 시에는 그 엔진·가중치·음색 자산의 조건을 각각 적용해요. 사전 제작 오디오도 모델 이용 조건 확인 대상이에요.

## 도입 판단용 실험

다음은 보장 성능이나 공식 기준이 아닌 제안 평가 방식이에요.

- 기존 API를 기준군으로 두고 영어·한국어 실제 대화 50개 이상을 비교해요. STT는 동의받은 학습자 녹음과 사람이 확인한 전사를 사용해요.
- STT: WER/CER, 부정어·시제·복수형 보존, 무음 환각, 학습자 문법 오류의 임의 보정을 평가해요.
- TTS: 원문 누락·반복·숫자·고유명사 발음, 자연스러움, 문장 사이 침묵을 청취해요.
- 첫 실행과 모델 상주 상태를 나누고 동시 요청 1·3·5개에서 p50/p95, 대기열, 최대 RAM, CPU, 오류율을 측정해요.
- 현재 지표는 전체 TTS 수신 시간이에요. 향후 스트리밍 시험에서는 첫 오디오 수신과 앱 첫 재생을 추가로 비교해요.
- 기존 대비 품질 저하가 없고 목표 동시성에서 지연이 허용되며 월 총비용이 낮을 때만 채택해요. 총비용에는 추가 CPU 서버·저장소·트래픽·fallback API·운영 시간을 포함해요.

서버 사양과 사용량이 없는 현재 단계에서 절감률·필요 서버 대수·응답 속도를 확정할 수는 없어요. 우선 권장 조합은 **기존 API STT + Supertonic-3 CPU TTS의 비교 실험**이에요.
