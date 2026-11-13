# App Store 검색 결과 크리에이티브 이미지

기존 1206 × 2622px 파일은 iPhone 세로 스크린샷 규격이며, Search results Creative Asset 업로드 칸에서 사용할 수 없어요.

사용 순서:

1. FreeChat
2. FreeChat 주제 준비
3. 대화 및 문법 피드백
4. Role Playing

각 화면에 원본 앱 캡처와 토마토 잎을 사용했어요. `*-search-3840x2560.png` 또는 `*-search-1920x1280.png`가 Search results 제출용이에요. `*-universal-5244x2950.png`는 Universal asset 제출용이에요. 배경색과 레이아웃은 세 크기에 맞춰 조정했으며 원본 앱 UI는 수정하지 않았어요.

Search results Creative Asset 자리에는 한 이미지를 선택해요. 네 화면이 검색 결과에서 나란히 보이는 구성을 원하면 크리에이티브 이미지 대신 `../portrait_screenshots/`의 네 파일을 App Previews and Screenshots 탭에 순서대로 올려야 해요. `preview-search-results-four-options.png`는 네 가지 가로형 후보의 비교용이에요.
`tomatalk-search-recommended-3840x2560.png`와 `tomatalk-search-recommended-1920x1280.png`는 대화 중 문법 피드백 화면을 크게 잘라 보여주는 단일 Search Results 권장안이에요. `render_recommended.swift`로 재생성해요.

Apple의 크리에이티브 이미지 안전 영역에서 제목과 화면의 주요 부분이 보이도록 설계했어요. 전체 앱 화면이 필요한 경우 `../portrait_screenshots/`의 세로 스크린샷을 사용해요.

생성: `swift render.swift`
