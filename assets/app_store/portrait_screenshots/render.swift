import AppKit
import CoreText
import Foundation

let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let width = 1206
let height = 2622
let background = NSColor(srgbRed: 0.93, green: 0.25, blue: 0.16, alpha: 1).cgColor

struct Page {
    let name: String
    let title: [String]
}

let pages = [
    Page(name: "01-freechat", title: ["하고 싶은 이야기로", "영어 대화 시작"]),
    Page(name: "02-topic-preparation", title: ["내 주제에 맞는", "첫 질문 고르기"]),
    Page(name: "03-conversation-feedback", title: ["대화하면서", "문법 피드백 받기"]),
    Page(name: "04-role-playing", title: ["실전 상황도", "역할극으로 연습"]),
]

func makeContext() -> CGContext {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.interpolationQuality = .high
    context.setFillColor(background)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context
}

func drawTitle(_ context: CGContext, _ lines: [String], fontSize initialSize: CGFloat = 116,
               firstBaseline: CGFloat = 2488, lineSpacing: CGFloat = 137) {
    for (index, text) in lines.enumerated() {
        var fontSize = initialSize
        var line: CTLine!
        repeat {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
                .foregroundColor: NSColor.white.cgColor,
            ]
            line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            if CTLineGetTypographicBounds(line, nil, nil, nil) <= 1080 { break }
            fontSize -= 2
        } while fontSize >= 88
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        context.textPosition = CGPoint(x: (CGFloat(width) - lineWidth) / 2,
                                       y: firstBaseline - CGFloat(index) * lineSpacing)
        CTLineDraw(line, context)
    }
}

func drawScreen(_ context: CGContext, _ image: CGImage,
                screenWidth: CGFloat = 1066, top: CGFloat = 365) {
    // 화면 전체를 유지하면서 아래쪽 60px만 출력 영역 밖으로 흘려보내요.
    let screenHeight = screenWidth * CGFloat(image.height) / CGFloat(image.width)
    let frame = CGRect(x: (CGFloat(width) - screenWidth) / 2,
                       y: CGFloat(height) - top - screenHeight,
                       width: screenWidth, height: screenHeight)
    let path = CGPath(roundedRect: frame, cornerWidth: 56, cornerHeight: 56, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28,
                      color: NSColor.black.withAlphaComponent(0.26).cgColor)
    context.setFillColor(NSColor.white.cgColor)
    context.addPath(path)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(path)
    context.clip()
    context.draw(image, in: frame)
    context.restoreGState()

    context.setStrokeColor(NSColor.black.withAlphaComponent(0.13).cgColor)
    context.setLineWidth(2)
    context.addPath(path)
    context.strokePath()
}

func save(_ context: CGContext, to url: URL) throws {
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    let data = bitmap.representation(using: .png, properties: [:])!
    try data.write(to: url)
}

for page in pages {
    let sourceURL = directory.appendingPathComponent("source/\(page.name).png")
    guard let image = NSImage(contentsOf: sourceURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("화면 캡처를 읽지 못했어요: \(sourceURL.path)")
    }
    let context = makeContext()
    drawTitle(context, page.title)
    drawScreen(context, image)
    try save(context, to: directory.appendingPathComponent("\(page.name)-1206x2622.png"))
}

// 원본 캡처를 그대로 사용해 네 장 모두 동일한 잎 배치 시안을 만들어요.
let leafSourceURL = directory.appendingPathComponent("source/tomato_leaf.png")
let leafImage = NSImage(contentsOf: leafSourceURL)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let leafCrop = leafImage.cropping(to: CGRect(x: 260, y: 95, width: 700, height: 450))!
let leafFrame = CGRect(x: 488, y: CGFloat(height) - 16 - 148, width: 230, height: 148)
for page in pages {
    let sourceURL = directory.appendingPathComponent("source/\(page.name).png")
    let image = NSImage(contentsOf: sourceURL)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let leafVariant = makeContext()
    leafVariant.saveGState()
    leafVariant.setShadow(offset: CGSize(width: 0, height: -4), blur: 10,
                          color: NSColor.white.withAlphaComponent(0.45).cgColor)
    leafVariant.draw(leafCrop, in: leafFrame)
    leafVariant.restoreGState()
    drawTitle(leafVariant, page.title, fontSize: 104,
              firstBaseline: 2368, lineSpacing: 112)
    drawScreen(leafVariant, image, screenWidth: 1040, top: 410)
    try save(leafVariant, to: directory.appendingPathComponent("\(page.name)-leaf-1206x2622.png"))

    // 같은 디자인을 또 다른 허용 iPhone 크기로 내보내요. 가로 비율을 유지하고 위아래만 약 4px 잘라요.
    let smaller = CGContext(
        data: nil, width: 1179, height: 2556,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    smaller.interpolationQuality = .high
    smaller.setFillColor(background)
    smaller.fill(CGRect(x: 0, y: 0, width: 1179, height: 2556))
    let scaledHeight = CGFloat(height) * 1179 / CGFloat(width)
    smaller.draw(leafVariant.makeImage()!, in: CGRect(x: 0, y: (2556 - scaledHeight) / 2,
                                                      width: 1179, height: scaledHeight))
    try save(smaller, to: directory.appendingPathComponent("\(page.name)-leaf-1179x2556.png"))
}

// 네 장의 순서를 한눈에 확인하는 미리보기예요. App Store 제출용은 개별 PNG예요.
func makePreview(suffix: String, filename: String) throws {
    let previewWidth = 1524
    let previewHeight = 823
    let preview = CGContext(
        data: nil, width: previewWidth, height: previewHeight,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    preview.interpolationQuality = .high
    preview.setFillColor(NSColor(calibratedWhite: 0.97, alpha: 1).cgColor)
    preview.fill(CGRect(x: 0, y: 0, width: previewWidth, height: previewHeight))
    for (index, page) in pages.enumerated() {
        let outputURL = directory.appendingPathComponent("\(page.name)\(suffix)-1206x2622.png")
        let image = NSImage(contentsOf: outputURL)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        preview.draw(image, in: CGRect(x: 18 + index * 376, y: 20, width: 360, height: 783))
    }
    try save(preview, to: directory.appendingPathComponent(filename))
}
try makePreview(suffix: "", filename: "preview-four-screens.png")
try makePreview(suffix: "-leaf", filename: "preview-four-screens-leaf.png")
