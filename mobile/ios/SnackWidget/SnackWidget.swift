import AppIntents
import SwiftUI
import WidgetKit

struct OpenSnackBasketIntent: AppIntent {
  static var title: LocalizedStringResource = "바구니에서 토마토 꺼내기"
  static var openAppWhenRun = false

  func perform() async throws -> some IntentResult {
    guard var snapshot = SnackWidgetStore.current(),
          snapshot.basket.consumed < 12,
          snapshot.basket.consumed % 4 == 0,
          snapshot.showingContent != true else {
      return .result()
    }
    snapshot.showingTomato = true
    SnackWidgetStore.save(snapshot)
    return .result()
  }
}

struct TakeSnackBiteIntent: AppIntent {
  static var title: LocalizedStringResource = "토마토 한입"
  static var openAppWhenRun = false

  func perform() async throws -> some IntentResult {
    guard var snapshot = SnackWidgetStore.current(),
          snapshot.isTomatoOut,
          snapshot.showingContent != true else {
      return .result()
    }
    snapshot.basket.consumed += 1
    snapshot.page = 0
    snapshot.showingContent = true
    snapshot.showingTomato = snapshot.basket.consumed % 4 != 0
    SnackWidgetStore.save(snapshot)
    return .result()
  }
}

struct CloseSnackContentIntent: AppIntent {
  static var title: LocalizedStringResource = "스낵 닫기"
  static var openAppWhenRun = false

  func perform() async throws -> some IntentResult {
    guard var snapshot = SnackWidgetStore.current() else { return .result() }
    snapshot.showingContent = false
    snapshot.page = 0
    SnackWidgetStore.save(snapshot)
    return .result()
  }
}

struct ShowSnackPageIntent: AppIntent {
  static var title: LocalizedStringResource = "스낵 내용 넘기기"
  static var openAppWhenRun = false

  @Parameter(title: "방향") var direction: Int

  init() {}

  init(direction: Int) {
    self.direction = direction
  }

  func perform() async throws -> some IntentResult {
    guard var snapshot = SnackWidgetStore.current(), snapshot.showingContent == true else {
      return .result()
    }
    let last = max(snapshot.pairedPages.count - 1, 0)
    let current = min(max(snapshot.page, 0), last)
    snapshot.page = min(max(current + direction, 0), last)
    SnackWidgetStore.save(snapshot)
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

  private var isLarge: Bool { family == .systemLarge }

  var body: some View {
    Group {
      if let snapshot = entry.snapshot,
         snapshot.showingContent == true,
         let snack = snapshot.currentSnack,
         !snapshot.pairedPages.isEmpty {
        contentCard(snapshot: snapshot, snack: snack)
      } else {
        tomatoCard
      }
    }
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
    .containerBackground(Color(red: 1, green: 0.97, blue: 0.94), for: .widget)
  }

  private var tomatoTitle: some View {
    Text("오늘의 토마토")
      .font(.system(size: isLarge ? 17 : 16, weight: .bold))
      .lineLimit(1)
      .minimumScaleFactor(0.8)
  }

  private func tomatoControl(size: CGFloat) -> some View {
    Group {
      if let snapshot = entry.snapshot, snapshot.basket.consumed < 12 {
        if snapshot.isTomatoOut {
          Button(intent: TakeSnackBiteIntent()) {
            tomatoImage(snapshot.basket.consumed, size: size)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("토마토 한입 먹기")
        } else {
          Button(intent: OpenSnackBasketIntent()) {
            basketImage(snapshot.basket.consumed, size: size)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("바구니에서 토마토 꺼내기")
        }
      } else {
        basketImage(entry.snapshot?.basket.consumed ?? 0, size: size)
      }
    }
  }

  private func contentCard(snapshot: SnackWidgetSnapshot, snack: SnackWidgetContent) -> some View {
    let pages = snapshot.pairedPages
    let page = min(max(snapshot.page, 0), pages.count - 1)
    return VStack(alignment: .leading, spacing: isLarge ? 8 : 2) {
      HStack {
        Text(typeLabel(snack.contentType))
          .font(.system(size: isLarge ? 15 : 12, weight: .semibold))
        Spacer()
        Text("\(snapshot.basket.consumed) / 12")
          .font(.system(size: isLarge ? 12 : 10, weight: .medium))
          .foregroundStyle(.secondary)
        Button(intent: CloseSnackContentIntent()) {
          Image(systemName: "xmark")
            .font(.system(size: isLarge ? 13 : 11, weight: .semibold))
            .frame(width: isLarge ? 34 : 24, height: isLarge ? 34 : 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("스낵 닫기")
      }

      HStack(alignment: .top, spacing: isLarge ? 8 : 6) {
        ForEach(snack.payload.items.indices, id: \.self) { index in
          expressionCard(snack.payload.items[index])
        }
      }

      if isLarge {
        Rectangle().fill(Color.black.opacity(0.12)).frame(height: 1)
      }

      if let secondaryTitle = pages[page].secondaryTitle,
         let secondaryBody = pages[page].secondaryBody {
        HStack(alignment: .top, spacing: isLarge ? 8 : 6) {
          pairedExplanation(title: pages[page].title, body: pages[page].body)
          pairedExplanation(title: secondaryTitle, body: secondaryBody)
        }
      } else {
        Text(pages[page].title)
          .font(.system(size: isLarge ? 14 : 11, weight: .semibold))
          .lineLimit(isLarge ? 2 : 1)
        Text(pages[page].body)
          .font(.system(size: isLarge ? 14 : 12))
          .lineLimit(isLarge ? 7 : 3)
          .minimumScaleFactor(0.85)
      }
      Spacer(minLength: 0)

      if pages.count > 1 {
        HStack {
          Button(intent: ShowSnackPageIntent(direction: -1)) {
            Image(systemName: "chevron.left")
              .frame(width: isLarge ? 40 : 30, height: isLarge ? 32 : 22)
          }
          .disabled(page == 0)
          Spacer()
          Text("\(page + 1) / \(pages.count)")
            .font(.system(size: isLarge ? 12 : 10))
            .foregroundStyle(.secondary)
          Spacer()
          Button(intent: ShowSnackPageIntent(direction: 1)) {
            Image(systemName: "chevron.right")
              .frame(width: isLarge ? 40 : 30, height: isLarge ? 32 : 22)
          }
          .disabled(page == pages.count - 1)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(isLarge ? 16 : 9)
    .containerBackground(backgroundColor(snack.contentType), for: .widget)
  }

  private func pairedExplanation(title: String, body: String) -> some View {
    VStack(alignment: .leading, spacing: isLarge ? 4 : 2) {
      Text(title)
        .font(.system(size: isLarge ? 13 : 10, weight: .semibold))
        .lineLimit(1)
        .truncationMode(.tail)
      Text(body)
        .font(.system(size: isLarge ? 12 : 10))
        .lineLimit(isLarge ? 5 : 2)
        .truncationMode(.tail)
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  private func expressionCard(_ item: SnackWidgetExpression) -> some View {
    VStack(alignment: .center, spacing: isLarge ? 3 : 1) {
      if let label = item.label {
        Text(label)
          .font(.system(size: isLarge ? 11 : 9, weight: .medium))
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
      }
      Text(item.expression)
        .font(.system(size: isLarge ? 16 : 14, weight: .bold))
        .lineLimit(isLarge ? 2 : 1)
        .minimumScaleFactor(0.7)
        .multilineTextAlignment(.center)
      if isLarge, let detail = item.usage ?? item.meaning {
        Text(detail)
          .font(.system(size: 11))
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, minHeight: isLarge ? 48 : 28, alignment: .top)
    .padding(isLarge ? 9 : 5)
    .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: isLarge ? 12 : 8))
  }

  private func tomatoImage(_ consumed: Int, size: CGFloat) -> some View {
    let stage = consumed % 4
    let name = ["TomatoWhole", "TomatoBite1", "TomatoBite2", "TomatoBite3", "TomatoBite4"][stage]
    return Image(name)
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
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
    case "usage_contrast": return Color(red: 0xDB / 255, green: 0xEA / 255, blue: 0xFE / 255)
    case "homonym": return Color(red: 0xE5 / 255, green: 0xF5 / 255, blue: 0xD3 / 255)
    default: return Color(red: 0xE8 / 255, green: 0xE4 / 255, blue: 0xF4 / 255)
    }
  }

  private func typeLabel(_ type: String) -> String {
    switch type {
    case "regional_variant": return "지역별 표현"
    case "usage_contrast": return "표현의 차이"
    default: return "동음이의어"
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
