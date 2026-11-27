import AppIntents
import SwiftUI
import WidgetKit

struct OpenSnackBasketIntent: AppIntent {
  static var title: LocalizedStringResource = "바구니에서 토마토 꺼내기"
  static var openAppWhenRun = false

  @MainActor func perform() async throws -> some IntentResult {
    guard var snapshot = SnackWidgetStore.current(),
          snapshot.basket.consumed < 12,
          snapshot.basket.consumed % 4 == 0,
          !snapshot.isTomatoOut,
          snapshot.showingContent != true else {
      return .result()
    }
    snapshot.showingTomato = true
    SnackWidgetStore.save(snapshot, reload: false)
    return .result()
  }
}

struct TakeSnackBiteIntent: AppIntent {
  static var title: LocalizedStringResource = "토마토 한입"
  static var openAppWhenRun = false

  @MainActor func perform() async throws -> some IntentResult {
    guard var snapshot = SnackWidgetStore.current(),
          snapshot.isTomatoOut,
          snapshot.showingContent != true else {
      return .result()
    }
    snapshot.basket.consumed += 1
    snapshot.page = 0
    snapshot.showingContent = true
    snapshot.showingTomato = snapshot.basket.consumed % 4 != 0
    SnackWidgetStore.save(snapshot, reload: false)
    return .result()
  }
}

struct CloseSnackContentIntent: AppIntent {
  static var title: LocalizedStringResource = "스낵 닫기"
  static var openAppWhenRun = false

  func perform() async throws -> some IntentResult {
    guard var snapshot = SnackWidgetStore.current() else { return .result() }
    snapshot.closeContent()
    SnackWidgetStore.save(snapshot, reload: false)
    return .result()
  }
}

struct ShowSnackPageIntent: AppIntent {
  static var title: LocalizedStringResource = "스낵 내용 넘기기"
  static var openAppWhenRun = false

  @Parameter(title: "방향") var direction: Int
  @Parameter(title: "페이지 수", default: 1) var pageCount: Int

  init() {}

  init(direction: Int, pageCount: Int) {
    self.pageCount = pageCount
    self.direction = direction
  }

  func perform() async throws -> some IntentResult {
    guard var snapshot = SnackWidgetStore.current(), snapshot.showingContent == true else {
      return .result()
    }
    let last = max(pageCount - 1, 0)
    let current = min(max(snapshot.page, 0), last)
    snapshot.page = min(max(current + direction, 0), last)
    SnackWidgetStore.save(snapshot, reload: false)
    return .result()
  }
}

struct SnackWidgetEntry: TimelineEntry {
  let date: Date
  let snapshot: SnackWidgetSnapshot?
}

struct SnackWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> SnackWidgetEntry {
    SnackWidgetEntry(date: .now, snapshot: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (SnackWidgetEntry) -> Void) {
    completion(SnackWidgetEntry(date: .now, snapshot: SnackWidgetStore.current()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SnackWidgetEntry>) -> Void) {
    let entry = SnackWidgetEntry(date: .now, snapshot: SnackWidgetStore.current())
    completion(Timeline(entries: [entry], policy: .after(SnackWidgetStore.nextMidnight())))
  }
}

struct SnackWidgetView: View {
  let entry: SnackWidgetEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var isLarge: Bool { family == .systemLarge }
  private var tomatoBackground: Color { Color(red: 1, green: 0.97, blue: 0.94) }

  private var widgetBackground: Color {
    if let snapshot = entry.snapshot,
       snapshot.showingContent == true,
       let snack = snapshot.currentSnack,
       !snapshot.pairedPages.isEmpty {
      return backgroundColor(snack.contentType)
    }
    return tomatoBackground
  }

  var body: some View {
    Group {
      if let snapshot = entry.snapshot,
         snapshot.showingContent == true,
         let snack = snapshot.currentSnack,
         !snapshot.pairedPages.isEmpty {
        contentCard(snapshot: snapshot, snack: snack)
          .transition(.identity)
      } else {
        tomatoCard
          .transition(.identity)
      }
    }
    .containerBackground(widgetBackground, for: .widget)
  }

  private var tomatoCard: some View {
    Group {
      if isLarge {
        tomatoControl(size: 150)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .overlay(alignment: .top) { tomatoTitle }
          .padding(18)
      } else {
        VStack(spacing: 8) {
          tomatoTitle
          tomatoControl(size: 96)
          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(12)
      }
    }
    .background(tomatoBackground)
  }

  private var tomatoTitle: some View {
    Text("오늘의 토마토")
      .font(.system(size: isLarge ? 17 : 16, weight: .bold))
      .lineLimit(1)
      .minimumScaleFactor(0.8)
  }

  private func tomatoControl(size: CGFloat) -> some View {
    let snapshot = entry.snapshot
    let consumed = snapshot?.basket.consumed ?? 0
    let tomatoOut = snapshot?.isTomatoOut == true
    let stage = snapshot?.visibleTomatoStage ?? 0
    return ZStack {
      basketImage(consumed, size: size)
        .opacity(tomatoOut ? 0 : 1)
      tomatoImage(stage: stage, size: size)
        .opacity(tomatoOut ? 1 : 0)
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: tomatoOut)
    .overlay {
      if let snapshot, snapshot.basket.consumed < 12, snapshot.showingContent != true {
        if tomatoOut {
          Button(intent: TakeSnackBiteIntent()) { Color.clear.contentShape(Rectangle()) }
            .accessibilityLabel("토마토 한입 먹기")
        } else {
          Button(intent: OpenSnackBasketIntent()) { Color.clear.contentShape(Rectangle()) }
            .accessibilityLabel("바구니에서 토마토 꺼내기")
        }
      }
    }
    .buttonStyle(.plain)
  }

  private func contentCard(snapshot: SnackWidgetSnapshot, snack: SnackWidgetContent) -> some View {
    GeometryReader { geometry in
      let padding: CGFloat = isLarge ? 16 : 8
      let fontSize: CGFloat = isLarge ? 18 : 16
      let bodyHeight = max(20, geometry.size.height - padding * 2 - 92)
      let pages = snapshot.readingPages(width: geometry.size.width - padding * 2,
                                       height: bodyHeight, fontSize: fontSize)
      let page = min(max(snapshot.page, 0), max(0, pages.count - 1))
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(typeLabel(snack.contentType, language: snack.explanationLanguage))
            .font(.system(size: isLarge ? 15 : 12, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
          Spacer()
          Button(intent: CloseSnackContentIntent()) {
            Image(systemName: "xmark").frame(width: 28, height: 28)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(snack.explanationLanguage == "ko" ? "스낵 닫기" : "Close snack")
        }.frame(height: 28)
        if !pages.isEmpty {
          Text(pages[page].title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(height: 16, alignment: .leading)
          Text(pages[page].body.trimmingCharacters(in: .whitespacesAndNewlines))
            .font(.system(size: fontSize))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: bodyHeight, maxHeight: bodyHeight, alignment: .topLeading)
          Spacer(minLength: 0)
          HStack {
            Button(intent: ShowSnackPageIntent(direction: -1, pageCount: pages.count)) {
              Image(systemName: "chevron.left").frame(width: 40, height: 28)
            }.disabled(page == 0)
              .accessibilityLabel(snack.explanationLanguage == "ko" ? "이전 내용" : "Previous page")
            Spacer()
            Text("\(page + 1) / \(pages.count)").font(.system(size: 12))
            Spacer()
            Button(intent: ShowSnackPageIntent(direction: 1, pageCount: pages.count)) {
              Image(systemName: "chevron.right").frame(width: 40, height: 28)
            }.disabled(page == pages.count - 1)
              .accessibilityLabel(snack.explanationLanguage == "ko" ? "다음 내용" : "Next page")
          }.buttonStyle(.plain)
        }
      }
      .padding(padding)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .background(backgroundColor(snack.contentType))
  }

  private func tomatoImage(stage: Int, size: CGFloat) -> some View {
    let name = ["TomatoWhole", "TomatoBite1", "TomatoBite2", "TomatoBite3", "TomatoBite4"][stage]
    return Image(name)
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
      .contentTransition(.identity)
      .accessibilityHidden(true)
  }

  private func basketImage(_ consumed: Int, size: CGFloat) -> some View {
    let stage = min(consumed / 4, 3)
    let name = ["Basket3", "Basket2", "Basket1", "Basket0"][stage]
    return Image(name)
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }

  private func backgroundColor(_ type: String) -> Color {
    switch type {
    case "usage_contrast", "register_contrast": return Color(red: 0xDB / 255, green: 0xEA / 255, blue: 0xFE / 255)
    case "homonym", "collocation": return Color(red: 0xE5 / 255, green: 0xF5 / 255, blue: 0xD3 / 255)
    default: return Color(red: 0xE8 / 255, green: 0xE4 / 255, blue: 0xF4 / 255)
    }
  }

  private func typeLabel(_ type: String, language: String) -> String {
    switch type {
    case "register_contrast": return language == "ko" ? "상황에 맞는 말투" : "The right tone"
    case "collocation": return language == "ko" ? "함께 쓰면 자연스러운 말" : "Words that go together"
    case "idiomatic_expression": return language == "ko" ? "표현 속 숨은 뜻" : "Beyond literal meaning"
    case "regional_variant": return language == "ko" ? "지역마다 다른 표현" : "Regional expressions"
    case "usage_contrast": return language == "ko" ? "비슷하지만 다른 쓰임" : "Usage differences"
    default: return language == "ko" ? "같은 소리, 다른 뜻" : "Same sound, different meanings"
    }
  }
}

@main
struct SnackTomatoWidget: Widget {
  let kind = SnackWidgetStore.kind

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SnackWidgetProvider()) { entry in
      SnackWidgetView(entry: entry)
    }
    .configurationDisplayName("오늘의 토마토")
    .description("토마토를 한입씩 먹으며 오늘의 언어 스낵을 배워요.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}
