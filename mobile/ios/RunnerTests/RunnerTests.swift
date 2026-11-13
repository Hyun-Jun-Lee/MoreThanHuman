import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

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
    let tap = Date(timeIntervalSince1970: 1_000)
    XCTAssertNil(snapshot.interaction(at: tap))
    snapshot.pickupStartedAt = tap.timeIntervalSince1970
    XCTAssertEqual(snapshot.interaction(at: tap), .pickup)
    XCTAssertNil(snapshot.interaction(at: tap.addingTimeInterval(5)))
    snapshot.basket.consumed = 4
    snapshot.showingTomato = false
    XCTAssertFalse(snapshot.isTomatoOut)
    XCTAssertNil(snapshot.interaction(at: tap))
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
    snapshot.bitePreviewStartedAt = 1_000
    for consumed in 1...12 {
      snapshot.basket.consumed = consumed
      XCTAssertEqual(snapshot.visibleTomatoStage, (consumed - 1) % 4 + 1)
      XCTAssertEqual(snapshot.interaction(at: tap.addingTimeInterval(1)), .bite)
    }
    XCTAssertNil(snapshot.interaction(at: tap.addingTimeInterval(5)))
    snapshot.showingContent = false
    XCTAssertNil(snapshot.interaction(at: tap.addingTimeInterval(1)))
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

}
