# Concepts

이 프로젝트의 공유 도메인 용어집이에요. 엔티티, 이름 붙은 프로세스, 상태 개념처럼 프로젝트 안에서 특별한 의미를 갖는 말을 정의해요. ce-compound와 ce-compound-refresh가 learning을 처리하면서 점진적으로 확장하며, 직접 편집해도 괜찮아요. 이 문서는 명세나 전체 용어 목록이 아니라 glossary예요.

## Topic Preparation

### Topic Prep Card
사용자의 관심 주제를 검색 기반 요약, 선택 가능한 conversation direction, 첫 질문으로 바꾸는 대화 시작 준비 카드예요.

Topic Prep Card 자체는 저장된 conversation이 아니에요. 클라이언트가 시작점으로 보여줘도 될 만큼 생성 구조가 완성됐는지 백엔드가 검증했을 때만 ready로 취급해요.

### Conversation Direction
사용자가 Topic Prep Card에서 자유 대화를 시작하기 전에 선택하는 대화 방식이에요.

Conversation Direction은 첫 질문과 이후 prompt 흐름을 형성해요. 자유 입력 문자열이 아니라 닫힌 API contract 값이에요.

### Ready State
생성된 결과를 클라이언트가 완성된 상태로 보여줘도 된다고 백엔드가 검증한 상태예요.

LLM 기반 흐름에서 Ready State는 모델의 품질 판단만으로 결정되지 않고, 서비스의 결정적 검증을 함께 통과해야 해요.

### Retry Guidance
주제나 생성 결과가 사용자에게 보여주기에는 부족할 때 반환하는 회복 안내예요.

Retry Guidance는 불완전한 출력을 성공 경험으로 포장하지 않고, 사용자가 더 구체적인 입력으로 다시 시도할 수 있게 해요.

## Conversation

### Multimodal Conversation Turn
진행 중인 conversation에 사용자가 텍스트 또는 녹음 파일 중 하나를 입력으로 보내는 한 번의 대화 차례예요.

녹음 파일은 백엔드 STT를 거쳐 transcript가 canonical user message가 되고, 선택적으로 assistant response의 TTS audio가 같은 응답에 포함될 수 있어요.
