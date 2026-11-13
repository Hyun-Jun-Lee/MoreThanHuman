import AppIntents
import SwiftUI
import UIKit
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
    snapshot.pickupStartedAt = UIAccessibility.isReduceMotionEnabled ? nil : Date().timeIntervalSince1970
    snapshot.bitePreviewStartedAt = nil
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
    if let start = snapshot.pickupStartedAt,
       (0..<SnackWidgetMotion.pickup.duration).contains(Date().timeIntervalSince1970 - start) {
      return .result()
    }
    snapshot.basket.consumed += 1
    snapshot.page = 0
    snapshot.showingContent = true
    snapshot.showingTomato = snapshot.basket.consumed % 4 != 0
    snapshot.pickupStartedAt = nil
    snapshot.bitePreviewStartedAt = UIAccessibility.isReduceMotionEnabled ? nil : Date().timeIntervalSince1970
    SnackWidgetStore.save(snapshot, reload: false)
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
    snapshot.bitePreviewStartedAt = nil
    SnackWidgetStore.save(snapshot, reload: false)
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
    snapshot.bitePreviewStartedAt = nil
    SnackWidgetStore.save(snapshot, reload: false)
    return .result()
  }
}

struct SnackWidgetEntry: TimelineEntry {
  let date: Date
  let snapshot: SnackWidgetSnapshot?
  let motion: SnackWidgetMotion?
  var progress: Double = 1
}

struct SnackWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> SnackWidgetEntry {
    SnackWidgetEntry(date: .now, snapshot: nil, motion: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (SnackWidgetEntry) -> Void) {
    completion(SnackWidgetEntry(date: .now, snapshot: SnackWidgetStore.current(), motion: nil))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SnackWidgetEntry>) -> Void) {
    let now = Date()
    let snapshot = SnackWidgetStore.current()
    var entries: [SnackWidgetEntry] = []
    var settledDate = now
    if let motion = snapshot?.interaction(at: now) {
      for progress in motion.keyframes {
        let date = now.addingTimeInterval(progress * motion.duration)
        entries.append(SnackWidgetEntry(date: date, snapshot: snapshot, motion: motion, progress: progress))
      }
      settledDate = now.addingTimeInterval(motion.duration)
    }
    entries.append(SnackWidgetEntry(date: settledDate, snapshot: snapshot, motion: nil))
    completion(Timeline(entries: entries, policy: .after(SnackWidgetStore.nextMidnight())))
  }
}

struct SnackWidgetView: View {
  let entry: SnackWidgetEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var isLarge: Bool { family == .systemLarge }
  private var tomatoBackground: Color { Color(red: 1, green: 0.97, blue: 0.94) }
  private var biting: Bool { !reduceMotion && entry.motion == .bite }

  private var widgetBackground: Color {
    if !biting,
       let snapshot = entry.snapshot,
       snapshot.showingContent == true,
       let snack = snapshot.currentSnack,
       !snapshot.pairedPages.isEmpty {
      return backgroundColor(snack.contentType)
    }
    return tomatoBackground
  }

  var body: some View {
    Group {
      if !biting,
         let snapshot = entry.snapshot,
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

  private static let travelCurve = UnitCurve.bezier(
    startControlPoint: UnitPoint(x: 0.215, y: 0.61), endControlPoint: UnitPoint(x: 0.355, y: 1))
  private static let reboundCurve = UnitCurve.bezier(
    startControlPoint: UnitPoint(x: 0.175, y: 0.885), endControlPoint: UnitPoint(x: 0.32, y: 1.275))

  private func tomatoControl(size: CGFloat) -> some View {
    let snapshot = entry.snapshot
    let consumed = snapshot?.basket.consumed ?? 0
    let tomatoOut = snapshot?.isTomatoOut == true || biting
    let pickup = entry.motion == .pickup && !reduceMotion
    let stage = snapshot?.visibleTomatoStage ?? 0
    let progress = entry.progress
    let pickupProgress = pickup ? progress : (tomatoOut ? 1.0 : 0.0)
    let travel = Self.travelCurve.value(at: pickupProgress)
    let biteProgress = biting ? progress : 0
    let biteScale = biteProgress < 0.35
      ? 1 - 0.08 * biteProgress / 0.35
      : 0.92 + 0.08 * Self.reboundCurve.value(at: (biteProgress - 0.35) / 0.65)
    let displayedStage = biting && progress < 0.35 ? max(0, stage - 1) : stage
    return ZStack {
      basketImage(consumed, size: size)
        .offset(y: 12 * travel)
        .opacity(1 - UnitCurve.easeOut.value(at: min(pickupProgress / 0.7, 1)))
      tomatoImage(stage: displayedStage, size: size)
        .rotationEffect(.radians(sin(biteProgress * 2 * .pi) * 0.035))
        .scaleEffect((0.42 + 0.58 * Self.reboundCurve.value(at: pickupProgress)) * biteScale)
        .offset(x: 24 * (1 - travel), y: 30 * (1 - travel))
        .opacity(UnitCurve.easeOut.value(at: min(pickupProgress / 0.18, 1)))
    }
    // WidgetKit이 항목 사이에 기본 페이드나 스프링을 덧붙이지 않게 해요.
    .animation(nil, value: entry.date)
    .overlay {
      if let snapshot, snapshot.basket.consumed < 12, snapshot.showingContent != true,
         !pickup {
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
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundColor(snack.contentType))
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
