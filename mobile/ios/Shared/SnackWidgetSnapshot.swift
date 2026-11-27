import Foundation
import WidgetKit
import UIKit

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

  var pages: [SnackWidgetPage] { readingPages(width: 260, height: 90, fontSize: 16) }
  var pairedPages: [SnackWidgetPage] { pages }

  func readingPages(width: CGFloat, height: CGFloat, fontSize: CGFloat) -> [SnackWidgetPage] {
    guard let snack = currentSnack else { return [] }
    let ko = snack.explanationLanguage == "ko"
    let payload = snack.payload
    var sections: [(String, String)] = []
    if snack.contentType == "idiomatic_expression" {
      sections.append((ko ? "실제 의미" : "Meaning", [payload.expression, payload.meaning].compactMap { $0 }.joined(separator: "\n")))
      sections.append((ko ? "이렇게 써요" : "In conversation", [payload.example, payload.exampleTranslation].compactMap { $0 }.joined(separator: "\n\n")))
      sections.append((ko ? "언제 쓰나요?" : "When to use it", payload.usage ?? ""))
      sections.append((ko ? "말 그대로 풀면" : "Literally", payload.literalMeaning ?? ""))
    } else {
      let cores = payload.displayItems.map { item in
        [item.label.map { snackDisplayLabel($0, korean: ko) }, Optional(item.expression), item.meaning ?? item.usage]
          .compactMap { $0 }.joined(separator: "\n")
      }
      let context = [payload.meaning, payload.headword].compactMap { $0 }.joined(separator: "\n")
      sections.append((ko ? "표현 비교" : "Compare", ([context] + cores).filter { !$0.isEmpty }.joined(separator: "\n\n")))
      if let situation = payload.situation {
        sections.append((ko ? "이런 상황에서" : "Situation", situation))
      }
      for item in payload.displayItems {
        if let example = item.example {
          sections.append((ko ? "이렇게 써요" : "In conversation", [Optional(item.expression), Optional(example), item.exampleTranslation].compactMap { $0 }.joined(separator: "\n\n")))
        }
      }
    }
    return sections.flatMap { title, body in
      snackTextChunks(body, width: width, height: height, fontSize: fontSize).enumerated().map { index, chunk in
        SnackWidgetPage(title: index == 0 ? title : "\(title) · \(ko ? "계속" : "continued")", body: chunk)
      }
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

// 실제 글꼴과 가용 영역으로 분할하며 공백·줄바꿈도 버리지 않아요.
func snackTextChunks(_ text: String, width: CGFloat, height: CGFloat, fontSize: CGFloat) -> [String] {
  guard !text.isEmpty else { return [] }
  let font = UIFont.systemFont(ofSize: fontSize)
  let characters = Array(text)
  var offset = 0
  var chunks: [String] = []
  while offset < characters.count {
    var low = 1
    var high = characters.count - offset
    var fit = 1
    while low <= high {
      let length = (low + high) / 2
      let candidate = String(characters[offset..<(offset + length)]).trimmingCharacters(in: .whitespacesAndNewlines)
      let rect = (candidate as NSString).boundingRect(
        with: CGSize(width: max(1, width - 4), height: CGFloat.greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: font], context: nil)
      if ceil(rect.height) <= max(font.lineHeight, height - 4) {
        fit = length
        low = length + 1
      } else { high = length - 1 }
    }
    if offset + fit < characters.count, fit > 1,
       let boundary = characters[offset..<(offset + fit)].lastIndex(where: { $0.isWhitespace }),
       boundary > offset {
      fit = boundary - offset + 1
    }
    // 공백 경계로 되돌리면 마지막 줄바꿈이 빈 줄을 만들 수 있어 다시 측정해요.
    while fit > 1 {
      let finalText = String(characters[offset..<(offset + fit)]).trimmingCharacters(in: .whitespacesAndNewlines)
      let bounds = (finalText as NSString).boundingRect(
        with: CGSize(width: max(1, width - 4), height: CGFloat.greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: font], context: nil)
      if ceil(bounds.height) <= max(font.lineHeight, height - 4) { break }
      fit -= 1
    }
    let chunk = String(characters[offset..<(offset + fit)])
    if chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !chunks.isEmpty {
      chunks[chunks.count - 1] += chunk
    } else {
      chunks.append(chunk)
    }
    offset += fit
  }
  return chunks
}

func snackDisplayLabel(_ label: String, korean: Bool) -> String {
  guard korean else { return label }
  switch label.lowercased() {
  case "formal": return "격식 있는 표현"
  case "informal": return "일상적인 표현"
  case "polite": return "정중한 표현"
  case "casual": return "편한 표현"
  default: return label
  }
}
