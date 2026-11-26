import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testWidgetRedrawCyclesCategoriesAndHonorsReplayPermission() throws {
    let items = ["one", "two"].map {
      SnackWidgetExpression(expression: $0, label: "label", meaning: "meaning",
        usage: "usage", example: "example", exampleTranslation: nil)
    }
    let candidates = (0..<30).map { index in
      let kind = SnackWidgetBasket.categoryOrder[index % 6]
      return SnackWidgetContent(id: "candidate-\(index)", contentType: kind,
        schemaVersion: 1, contentLanguage: "en", explanationLanguage: "ko",
        payload: SnackWidgetPayload(items: kind == "idiomatic_expression" ? nil : items,
          meaning: "meaning", situation: "situation", headword: "headword",
          expression: "expression", literalMeaning: "literal", usage: "usage", example: "example"),
        publishedAt: "2026-11-27", createdAt: "2026-11-27", updatedAt: "2026-11-27")
    }
    var snapshot = SnackWidgetSnapshot(userId: "user", language: "en",
      basket: SnackWidgetBasket(day: "2026-11-27", consumed: 12, resetId: "marker",
        snacks: Array(candidates.prefix(12)), candidates: candidates), page: 2, showingContent: true)
    XCTAssertTrue(snapshot.isValid)
    snapshot.closeContent()
    XCTAssertEqual(snapshot.basket.consumed, 12)
    snapshot.unlimitedReplayEnabled = true
    snapshot.closeContent()
    XCTAssertEqual(snapshot.basket.consumed, 0)
    XCTAssertEqual(snapshot.basket.resetId, "marker")
    XCTAssertEqual(snapshot.page, 0)
    XCTAssertFalse(snapshot.showingContent!)
    XCTAssertFalse(snapshot.showingTomato!)
    let expected = SnackWidgetBasket.categoryOrder + SnackWidgetBasket.categoryOrder
    var selections = Set<String>()
    for _ in 0..<10 {
      snapshot.redraw(day: "2026-11-28")
      XCTAssertEqual(snapshot.basket.snacks.map(\.contentType), expected)
      XCTAssertEqual(Set(snapshot.basket.snacks.map(\.id)).count, 12)
      XCTAssertEqual(snapshot.basket.candidates?.count, 30)
      selections.insert(snapshot.basket.snacks.map(\.id).joined(separator: ","))
    }
    XCTAssertGreaterThan(selections.count, 1)
    XCTAssertEqual(snapshot.basket.day, "2026-11-28")
    // 이전 스냅샷은 기존 카드만으로도 순환하며 권한이 없으면 반복하지 않아요.
    snapshot.basket.candidates = nil
    snapshot.unlimitedReplayEnabled = nil
    snapshot.redraw()
    XCTAssertEqual(snapshot.basket.snacks.map(\.contentType), expected)
    snapshot.basket.consumed = 12
    snapshot.closeContent()
    XCTAssertEqual(snapshot.basket.consumed, 12)
    snapshot.basket.candidates = []
    XCTAssertFalse(snapshot.isValid)
  }

  func testWidgetDecodesFlutterBasketSnapshot() throws {
    let snack = """
      {"id":"en-1","content_type":"regional_variant","schema_version":1,
      "content_language":"en","explanation_language":"ko",
      "payload":{"meaning":"같은 뜻이에요.","items":[
      {"label":"UK","expression":"biscuit"},
      {"label":"US","expression":"cookie"}]},
      "published_at":"2026-10-27T00:00:00Z",
      "created_at":"2026-10-27T00:00:00Z",
      "updated_at":"2026-10-27T00:00:00Z"}
      """
    let snacks = Array(repeating: snack, count: 12).joined(separator: ",")
    let json = """
      {"user_id":"user-1","language":"en","page":0,
      "basket":{"day":"2026-10-27","consumed":1,"reset_id":null,
      "snacks":[\(snacks)]}}
      """
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    var snapshot = try decoder.decode(SnackWidgetSnapshot.self, from: Data(json.utf8))
    XCTAssertTrue(snapshot.isValid)
    XCTAssertNil(snapshot.showingContent)
    XCTAssertNil(snapshot.showingTomato)
    XCTAssertEqual(snapshot.pages.first?.title, "공통 의미")
    XCTAssertEqual(snapshot.pages.first?.body, "같은 뜻이에요.")
    XCTAssertTrue(snapshot.isTomatoOut)
    snapshot.basket.consumed = 0
    XCTAssertFalse(snapshot.isTomatoOut)
    snapshot.showingTomato = true
    XCTAssertTrue(snapshot.isTomatoOut)
    snapshot.basket.consumed = 4
    snapshot.showingTomato = false
    XCTAssertFalse(snapshot.isTomatoOut)
    snapshot.showingContent = true
    XCTAssertEqual(snapshot.visibleTomatoStage, 4)
    snapshot.showingContent = false
    XCTAssertEqual(snapshot.visibleTomatoStage, 0)
    snapshot.showingTomato = true
    XCTAssertTrue(snapshot.isTomatoOut)
    snapshot.basket.consumed = 12
    XCTAssertFalse(snapshot.isTomatoOut)
    snapshot.showingContent = true
    XCTAssertEqual(snapshot.visibleTomatoStage, 4)
    for consumed in 1...12 {
      snapshot.basket.consumed = consumed
      XCTAssertEqual(snapshot.visibleTomatoStage, (consumed - 1) % 4 + 1)
    }
  }

  func testUsageContrastStartsWithActualContent() throws {
    let snack = SnackWidgetContent(
      id: "en-2",
      contentType: "usage_contrast",
      schemaVersion: 1,
      contentLanguage: "en",
      explanationLanguage: "ko",
      payload: SnackWidgetPayload(items: [
        SnackWidgetExpression(
          expression: "say", label: nil, meaning: nil,
          usage: "말하는 내용에 초점을 둬요.", example: "Say hello.",
          exampleTranslation: "안녕하세요라고 말해요."
        ),
        SnackWidgetExpression(
          expression: "tell", label: nil, meaning: nil,
          usage: "듣는 사람에 초점을 둬요.", example: "Tell me.",
          exampleTranslation: "내게 말해요."
        ),
      ], meaning: nil),
      publishedAt: "2026-10-27T00:00:00Z",
      createdAt: "2026-10-27T00:00:00Z",
      updatedAt: "2026-10-27T00:00:00Z"
    )
    let snapshot = SnackWidgetSnapshot(
      userId: "user-1",
      language: "en",
      basket: SnackWidgetBasket(day: "2026-10-27", consumed: 1, resetId: nil,
                                snacks: Array(repeating: snack, count: 12)),
      page: 0,
      showingContent: true
    )
    XCTAssertEqual(snapshot.pages.first?.title, "say · 사용 예시")
    XCTAssertEqual(snapshot.pages.first?.body, "말하는 내용에 초점을 둬요.")
    XCTAssertFalse(snapshot.pages.contains { $0.body == "표현을 비교해 보세요" })
    XCTAssertEqual(snapshot.pages.count, 6)
    XCTAssertEqual(snapshot.pairedPages.count, 3)
    XCTAssertEqual(snapshot.pairedPages.first?.title, "say · 사용 예시")
    XCTAssertEqual(snapshot.pairedPages.first?.body, "말하는 내용에 초점을 둬요.")
    XCTAssertEqual(snapshot.pairedPages.first?.secondaryTitle, "tell · 사용 예시")
    XCTAssertEqual(snapshot.pairedPages.first?.secondaryBody, "듣는 사람에 초점을 둬요.")
  }

  func testNewTypesDecodeAndRoundTripWithoutLosingPayload() throws {
    let payloads: [(String, [String: Any])] = [
      ("register_contrast", ["situation": "도움을 요청할 때", "items": [
        ["expression": "Help me", "label": "친구", "usage": "편하게", "example": "Help me."],
        ["expression": "Could you help?", "label": "정중하게", "usage": "공손하게", "example": "Could you help?"]]]),
      ("collocation", ["headword": "decision", "items": [
        ["expression": "make a decision", "meaning": "결정하다", "example": "Make a decision."],
        ["expression": "reach a decision", "meaning": "결정에 이르다", "example": "We reached a decision."]]]),
      ("idiomatic_expression", ["expression": "break the ice", "literal_meaning": "얼음을 깨다",
        "meaning": "어색함을 풀다", "usage": "첫 만남", "example": "A game broke the ice."])
    ]
    for (kind, payload) in payloads {
      let raw: [String: Any] = ["id": kind, "content_type": kind, "schema_version": 1,
        "content_language": "en", "explanation_language": "ko", "payload": payload,
        "published_at": "2026-11-26T00:00:00Z", "created_at": "2026-11-26T00:00:00Z", "updated_at": "2026-11-26T00:00:00Z"]
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      let snack = try decoder.decode(SnackWidgetContent.self, from: JSONSerialization.data(withJSONObject: raw))
      XCTAssertTrue(snack.isValid)
      let snapshot = SnackWidgetSnapshot(userId: "user", language: "en",
        basket: SnackWidgetBasket(day: "2026-11-26", consumed: 5, resetId: "reset", snacks: Array(repeating: snack, count: 12)), page: 0)
      XCTAssertTrue(snapshot.isValid)
      XCTAssertFalse(snapshot.pairedPages.isEmpty)
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      let encoded = try encoder.encode(snack)
      let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
      XCTAssertEqual(saved["payload"] as? NSDictionary, payload as NSDictionary)
      if kind == "idiomatic_expression" {
        XCTAssertEqual(snack.payload.displayItems.count, 1)
        XCTAssertEqual(snapshot.pairedPages.first?.title, "직역")
        XCTAssertTrue(snapshot.pairedPages.contains { $0.title == "실제 의미" && $0.body == "어색함을 풀다" })
        var broken = snack
        broken.payload.meaning = nil
        XCTAssertFalse(broken.isValid)
      }
    }
  }

}
