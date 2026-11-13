import Foundation
import WidgetKit

struct SnackWidgetSnapshot: Codable {
  var userId: String
  var language: String
  var basket: SnackWidgetBasket
  var page: Int
  var showingContent: Bool?
  var showingTomato: Bool? = nil
  var pickupStartedAt: Double? = nil
  var bitePreviewStartedAt: Double? = nil

  var isValid: Bool {
    !userId.isEmpty &&
      (language == "en" || language == "ko") &&
      (0...12).contains(basket.consumed) &&
      basket.snacks.count == 12 &&
      basket.snacks.allSatisfy { $0.contentLanguage == language }
  }

  var currentSnack: SnackWidgetContent? {
    guard basket.consumed > 0 else { return nil }
    return basket.snacks[basket.consumed - 1]
  }

  var isTomatoOut: Bool {
    basket.consumed < 12 &&
      (showingTomato == true || (basket.consumed > 0 && basket.consumed % 4 != 0))
  }

  var visibleTomatoStage: Int {
    if showingContent == true && basket.consumed > 0 && basket.consumed % 4 == 0 {
      return 4
    }
    return basket.consumed % 4
  }

  func interaction(at date: Date) -> SnackWidgetMotion? {
    let motion: SnackWidgetMotion
    let startedAt: Double?
    if showingContent == true {
      motion = .bite
      startedAt = bitePreviewStartedAt
    } else if isTomatoOut && basket.consumed % 4 == 0 {
      motion = .pickup
      startedAt = pickupStartedAt
    } else {
      return nil
    }
    guard let startedAt,
          (0..<5).contains(date.timeIntervalSince1970 - startedAt) else { return nil }
    return motion
  }

  var pages: [SnackWidgetPage] {
    guard let snack = currentSnack else { return [] }
    var result: [SnackWidgetPage] = []
    if let meaning = snack.payload.meaning {
      appendPages(title: "공통 의미", body: meaning, to: &result)
    }
    for item in snack.payload.items {
      if let usage = item.usage {
        appendPages(title: "\(item.expression) · 사용 예시", body: usage, to: &result)
      }
      if let meaning = item.meaning {
        appendPages(title: "\(item.expression) · 뜻", body: meaning, to: &result)
      }
      if let example = item.example {
        appendPages(title: "\(item.expression) · 예문", body: example, to: &result)
      }
      if let translation = item.exampleTranslation {
        appendPages(title: "\(item.expression) · 번역", body: translation, to: &result)
      }
    }
    return result
  }

  var pairedPages: [SnackWidgetPage] {
    guard let snack = currentSnack else { return [] }
    guard snack.payload.items.count == 2 else { return pages }
    var result: [SnackWidgetPage] = []
    if let meaning = snack.payload.meaning {
      appendPages(title: "공통 의미", body: meaning, to: &result)
    }

    let first = snack.payload.items[0]
    let second = snack.payload.items[1]
    let fields: [(String, KeyPath<SnackWidgetExpression, String?>)] = [
      ("사용 예시", \.usage),
      ("뜻", \.meaning),
      ("예문", \.example),
      ("번역", \.exampleTranslation),
    ]
    for (label, field) in fields {
      let firstBody = first[keyPath: field]
      let secondBody = second[keyPath: field]
      if let firstBody, let secondBody {
        result.append(SnackWidgetPage(
          title: "\(first.expression) · \(label)", body: firstBody,
          secondaryTitle: "\(second.expression) · \(label)", secondaryBody: secondBody
        ))
      } else {
        if let firstBody {
          appendPages(title: "\(first.expression) · \(label)", body: firstBody, to: &result)
        }
        if let secondBody {
          appendPages(title: "\(second.expression) · \(label)", body: secondBody, to: &result)
        }
      }
    }
    return result
  }

  private func appendPages(title: String, body: String, to pages: inout [SnackWidgetPage]) {
    var remaining = body[...]
    while !remaining.isEmpty {
      if remaining.count <= 70 {
        pages.append(SnackWidgetPage(title: title, body: String(remaining)))
        break
      }
      let limit = remaining.index(remaining.startIndex, offsetBy: 70)
      let breakPoint = remaining[..<limit].lastIndex(of: " ") ?? limit
      pages.append(SnackWidgetPage(title: title, body: String(remaining[..<breakPoint])))
      remaining = remaining[breakPoint...].drop(while: { $0 == " " })
    }
  }
}

enum SnackWidgetMotion {
  case pickup, bite

  // 서로 다른 타임라인 항목으로 게시해 위젯 호스트가 중간 자세를 그릴 수 있게 해요.
  var keyframes: [Double] {
    switch self {
    case .pickup: return [0, 0.09, 0.18, 0.35, 0.5, 0.7, 0.85]
    case .bite: return [0, 0.125, 0.25, 0.35, 0.5, 0.625, 0.75, 0.875, 0.97]
    }
  }

  var duration: TimeInterval {
    switch self {
    case .pickup: return 0.4
    case .bite: return 0.36
    }
  }
}

struct SnackWidgetBasket: Codable {
  var day: String
  var consumed: Int
  var resetId: String?
  var snacks: [SnackWidgetContent]
}

struct SnackWidgetContent: Codable {
  var id: String
  var contentType: String
  var schemaVersion: Int
  var contentLanguage: String
  var explanationLanguage: String
  var payload: SnackWidgetPayload
  var publishedAt: String
  var createdAt: String
  var updatedAt: String
}

struct SnackWidgetPayload: Codable {
  var items: [SnackWidgetExpression]
  var meaning: String?
}

struct SnackWidgetExpression: Codable {
  var expression: String
  var label: String?
  var meaning: String?
  var usage: String?
  var example: String?
  var exampleTranslation: String?
}

struct SnackWidgetPage {
  let title: String
  let body: String
  let secondaryTitle: String?
  let secondaryBody: String?

  init(title: String, body: String, secondaryTitle: String? = nil, secondaryBody: String? = nil) {
    self.title = title
    self.body = body
    self.secondaryTitle = secondaryTitle
    self.secondaryBody = secondaryBody
  }
}

enum SnackWidgetStore {
  static let group = "group.com.morethanhuman.curitalk"
  static let key = "snack.widget.snapshot.v1"
  static let kind = "SnackTomatoWidget"

  private static var defaults: UserDefaults? { UserDefaults(suiteName: group) }

  static func readRaw() -> String? { defaults?.string(forKey: key) }

  static func read() -> SnackWidgetSnapshot? {
    guard let raw = readRaw(), let data = raw.data(using: .utf8) else { return nil }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    guard let snapshot = try? decoder.decode(SnackWidgetSnapshot.self, from: data),
          snapshot.isValid else { return nil }
    return snapshot
  }

  static func saveRaw(_ raw: String, reload: Bool = true) -> Bool {
    guard let data = raw.data(using: .utf8) else { return false }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    guard let snapshot = try? decoder.decode(SnackWidgetSnapshot.self, from: data),
          snapshot.isValid, let defaults else { return false }
    defaults.set(raw, forKey: key)
    if reload { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
    return true
  }

  static func save(_ snapshot: SnackWidgetSnapshot, reload: Bool = true) {
    guard snapshot.isValid else { return }
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    guard let data = try? encoder.encode(snapshot),
          let raw = String(data: data, encoding: .utf8) else { return }
    _ = saveRaw(raw, reload: reload)
  }

  static func clear() {
    defaults?.removeObject(forKey: key)
    WidgetCenter.shared.reloadTimelines(ofKind: kind)
  }

  static func current() -> SnackWidgetSnapshot? {
    guard var snapshot = read() else { return nil }
    let today = dayString(Date())
    if snapshot.basket.day != today {
      snapshot.basket.day = today
      snapshot.basket.consumed = 0
      snapshot.page = 0
      snapshot.showingContent = false
      snapshot.showingTomato = false
      snapshot.pickupStartedAt = nil
      snapshot.bitePreviewStartedAt = nil
      save(snapshot)
    }
    return snapshot
  }

  static func nextMidnight() -> Date {
    Calendar.current.nextDate(
      after: Date(),
      matching: DateComponents(hour: 0, minute: 0, second: 0),
      matchingPolicy: .nextTime
    ) ?? Date().addingTimeInterval(86_400)
  }

  private static func dayString(_ date: Date) -> String {
    let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }
}
