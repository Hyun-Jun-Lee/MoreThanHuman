import Foundation
import WidgetKit

struct SnackWidgetSnapshot: Codable {
  var userId: String
  var language: String
  var basket: SnackWidgetBasket
  var page: Int
  var showingContent: Bool?
  var showingTomato: Bool? = nil
  var unlimitedReplayEnabled: Bool? = nil

  var isValid: Bool {
    !userId.isEmpty &&
      (language == "en" || language == "ko") &&
      (0...12).contains(basket.consumed) &&
      basket.snacks.count == 12 &&
      basket.snacks.allSatisfy { $0.contentLanguage == language && $0.isValid } &&
      (basket.candidates == nil || (
        !(basket.candidates?.isEmpty ?? true) && (basket.candidates?.count ?? 0) <= 30 &&
        basket.candidates!.allSatisfy { $0.contentLanguage == language && $0.isValid }
      ))
  }

  mutating func redraw(day: String? = nil) {
    basket.redraw()
    if let day { basket.day = day }
    page = 0
    showingContent = false
    showingTomato = false
  }

  mutating func closeContent() {
    showingContent = false
    page = 0
    if basket.consumed == 12 && unlimitedReplayEnabled == true {
      redraw()
    }
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

  var pages: [SnackWidgetPage] {
    guard let snack = currentSnack else { return [] }
    var result: [SnackWidgetPage] = []
    if snack.contentType == "idiomatic_expression" {
      let ko = snack.explanationLanguage == "ko"
      for (title, body) in [(ko ? "직역" : "Literal meaning", snack.payload.literalMeaning),
                            (ko ? "실제 의미" : "Actual meaning", snack.payload.meaning),
                            (ko ? "쓰임" : "Usage", snack.payload.usage),
                            (ko ? "예문" : "Example", snack.payload.example),
                            (ko ? "번역" : "Translation", snack.payload.exampleTranslation)] {
        if let body { appendPages(title: title, body: body, to: &result) }
      }
      return result
    }
    appendContext(snack, to: &result)
    if let meaning = snack.payload.meaning {
      appendPages(title: "공통 의미", body: meaning, to: &result)
    }
    for item in snack.payload.displayItems {
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
    guard snack.payload.displayItems.count == 2 else { return pages }
    var result: [SnackWidgetPage] = []
    appendContext(snack, to: &result)
    if let meaning = snack.payload.meaning {
      appendPages(title: "공통 의미", body: meaning, to: &result)
    }

    let first = snack.payload.displayItems[0]
    let second = snack.payload.displayItems[1]
    let fields: [(String, KeyPath<SnackWidgetExpression, String?>)] = [
      (snack.explanationLanguage == "ko" ? "사용 예시" : "Usage", \.usage),
      (snack.explanationLanguage == "ko" ? "뜻" : "Meaning", \.meaning),
      (snack.explanationLanguage == "ko" ? "예문" : "Example", \.example),
      (snack.explanationLanguage == "ko" ? "번역" : "Translation", \.exampleTranslation),
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

  private func appendContext(_ snack: SnackWidgetContent, to pages: inout [SnackWidgetPage]) {
    let ko = snack.explanationLanguage == "ko"
    if let situation = snack.payload.situation {
      appendPages(title: ko ? "상황" : "Situation", body: situation, to: &pages)
    }
    if let headword = snack.payload.headword {
      appendPages(title: ko ? "중심 단어" : "Headword", body: headword, to: &pages)
    }
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

struct SnackWidgetBasket: Codable {
  var day: String
  var consumed: Int
  var resetId: String?
  var snacks: [SnackWidgetContent]
  var candidates: [SnackWidgetContent]? = nil

  static let categoryOrder = [
    "regional_variant", "usage_contrast", "homonym",
    "register_contrast", "collocation", "idiomatic_expression",
  ]

  mutating func redraw() {
    var seen = Set<String>()
    let source = (candidates ?? snacks).filter { seen.insert($0.id).inserted }.shuffled()
    let groups = Dictionary(grouping: source, by: \.contentType)
    let available = Self.categoryOrder.filter { !(groups[$0]?.isEmpty ?? true) }
    guard !available.isEmpty else { return }
    snacks = (0..<12).map { index in
      let group = groups[available[index % available.count]]!
      return group[(index / available.count) % group.count]
    }
    consumed = 0
  }
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

  var isValid: Bool {
    schemaVersion == 1 &&
      (contentLanguage == "en" || contentLanguage == "ko") &&
      explanationLanguage == (contentLanguage == "en" ? "ko" : "en") &&
      payload.isValid(for: contentType)
  }
}

struct SnackWidgetPayload: Codable {
  var items: [SnackWidgetExpression]?
  var meaning: String?
  var situation: String? = nil
  var headword: String? = nil
  var expression: String? = nil
  var literalMeaning: String? = nil
  var usage: String? = nil
  var example: String? = nil
  var exampleTranslation: String? = nil

  var displayItems: [SnackWidgetExpression] {
    if let items { return items }
    guard let expression else { return [] }
    return [SnackWidgetExpression(expression: expression, label: nil, meaning: nil,
                                  usage: nil, example: nil, exampleTranslation: nil)]
  }

  func isValid(for type: String) -> Bool {
    func text(_ value: String?, _ max: Int) -> Bool {
      guard let value else { return false }
      return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.unicodeScalars.count <= max
    }
    if type == "idiomatic_expression" {
      return items == nil && text(expression, 80) && text(literalMeaning, 160) &&
        text(meaning, 160) && text(usage, 160) && text(example, 240) &&
        (exampleTranslation == nil || text(exampleTranslation, 240))
    }
    guard ["regional_variant", "usage_contrast", "homonym", "register_contrast", "collocation"].contains(type),
          let items, items.count == 2 else { return false }
    if type == "regional_variant" && !text(meaning, 160) { return false }
    if type == "register_contrast" && !text(situation, 160) { return false }
    if type == "collocation" && !text(headword, 80) { return false }
    return items.allSatisfy { item in
      guard text(item.expression, 80) else { return false }
      if ["regional_variant", "register_contrast"].contains(type) && !text(item.label, 48) { return false }
      if type == "regional_variant" { return true }
      if ["usage_contrast", "register_contrast"].contains(type) && !text(item.usage, 160) { return false }
      if ["homonym", "collocation"].contains(type) && !text(item.meaning, 160) { return false }
      return text(item.example, 240) && (item.exampleTranslation == nil || text(item.exampleTranslation, 240))
    }
  }
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
      snapshot.redraw(day: today)
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
