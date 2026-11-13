import AppKit
import CoreText
import Foundation

let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let sourceDirectory = directory.deletingLastPathComponent()
    .appendingPathComponent("portrait_screenshots/source", isDirectory: true)
let red = NSColor(srgbRed: 0.93, green: 0.25, blue: 0.16, alpha: 1).cgColor
let leafImage = NSImage(contentsOf: sourceDirectory.appendingPathComponent("tomato_leaf.png"))!
    .cgImage(forProposedRect: nil, context: nil, hints: nil)!
let leaf = leafImage.cropping(to: CGRect(x: 260, y: 95, width: 700, height: 450))!

struct Page {
    let name: String
    let lines: [String]
}

let pages = [
    Page(name: "01-freechat", lines: ["하고 싶은", "이야기로", "영어 대화 시작"]),
    Page(name: "02-topic-preparation", lines: ["내 주제에 맞는", "첫 질문", "고르기"]),
    Page(name: "03-conversation-feedback", lines: ["대화하면서", "문법 피드백", "받기"]),
    Page(name: "04-role-playing", lines: ["실전 상황도", "역할극으로", "연습"]),
]

func makeContext(width: Int, height: Int) -> CGContext {
    let context = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.interpolationQuality = .high
    context.setFillColor(red)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context
}

func drawLeaf(_ context: CGContext, canvasHeight: CGFloat,
              centerX: CGFloat, top: CGFloat, width: CGFloat) {
    let leafHeight = width * 450 / 700
    let frame = CGRect(x: centerX - width / 2,
                       y: canvasHeight - top - leafHeight,
                       width: width, height: leafHeight)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -5), blur: 14,
                      color: NSColor.white.withAlphaComponent(0.48).cgColor)
    context.draw(leaf, in: frame)
    context.restoreGState()
}

func drawTitle(_ context: CGContext, lines: [String], canvasHeight: CGFloat,
               centerX: CGFloat, maxWidth: CGFloat, top: CGFloat,
               maxFontSize: CGFloat, lineSpacing: CGFloat) {
    for (index, text) in lines.enumerated() {
        var fontSize = maxFontSize
        var line: CTLine!
        repeat {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
                .foregroundColor: NSColor.white.cgColor,
            ]
            line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            if CTLineGetTypographicBounds(line, nil, nil, nil) <= Double(maxWidth) { break }
            fontSize -= 2
        } while fontSize >= 72
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let baseline = canvasHeight - top - maxFontSize - CGFloat(index) * lineSpacing
        context.textPosition = CGPoint(x: centerX - lineWidth / 2, y: baseline)
        CTLineDraw(line, context)
    }
}

func drawScreen(_ context: CGContext, image: CGImage, canvasHeight: CGFloat,
                x: CGFloat, top: CGFloat, width: CGFloat, radius: CGFloat) {
    let screenHeight = width * CGFloat(image.height) / CGFloat(image.width)
    let frame = CGRect(x: x, y: canvasHeight - top - screenHeight,
                       width: width, height: screenHeight)
    let path = CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: -22, height: -18), blur: 55,
                      color: NSColor.black.withAlphaComponent(0.27).cgColor)
    context.setFillColor(NSColor.white.cgColor)
    context.addPath(path)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(path)
    context.clip()
    context.draw(image, in: frame)
    context.restoreGState()

    context.setStrokeColor(NSColor.black.withAlphaComponent(0.12).cgColor)
    context.setLineWidth(4)
    context.addPath(path)
    context.strokePath()
}

func write(_ context: CGContext, filename: String) throws {
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    let png = bitmap.representation(using: .png, properties: [:])!
    try png.write(to: directory.appendingPathComponent(filename))
}

for page in pages {
    let source = sourceDirectory.appendingPathComponent("\(page.name).png")
    guard let screen = NSImage(contentsOf: source)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("캡처를 읽지 못했어요: \(source.path)")
    }

    // Search results 3:2: 중앙 2168 × 1030px 안에서 제목과 앱의 핵심 UI가 보이게 해요.
    let search = makeContext(width: 3840, height: 2560)
    drawLeaf(search, canvasHeight: 2560, centerX: 1370, top: 830, width: 340)
    drawTitle(search, lines: page.lines, canvasHeight: 2560,
              centerX: 1370, maxWidth: 1030, top: 1110,
              maxFontSize: 145, lineSpacing: 166)
    drawScreen(search, image: screen, canvasHeight: 2560,
               x: 1900, top: 30, width: 1180, radius: 70)
    try write(search, filename: "\(page.name)-search-3840x2560.png")

    let small = makeContext(width: 1920, height: 1280)
    small.scaleBy(x: 0.5, y: 0.5)
    drawLeaf(small, canvasHeight: 2560, centerX: 1370, top: 830, width: 340)
    drawTitle(small, lines: page.lines, canvasHeight: 2560,
              centerX: 1370, maxWidth: 1030, top: 1110,
              maxFontSize: 145, lineSpacing: 166)
    drawScreen(small, image: screen, canvasHeight: 2560,
               x: 1900, top: 30, width: 1180, radius: 70)
    try write(small, filename: "\(page.name)-search-1920x1280.png")

    // Universal 16:9: 중앙 1402 × 962px 안전 영역에 맞춘 별도 구성.
    let universal = makeContext(width: 5244, height: 2950)
    drawLeaf(universal, canvasHeight: 2950, centerX: 2180, top: 805, width: 215)
    drawTitle(universal, lines: page.lines, canvasHeight: 2950,
              centerX: 2180, maxWidth: 550, top: 1020,
              maxFontSize: 88, lineSpacing: 106)
    drawScreen(universal, image: screen, canvasHeight: 2950,
               x: 2450, top: 510, width: 900, radius: 55)
    try write(universal, filename: "\(page.name)-universal-5244x2950.png")
}

// 확인용 2 × 2 미리보기. 제출할 때는 각 개별 파일을 선택해요.
let preview = CGContext(
    data: nil, width: 1920, height: 1320,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!
preview.interpolationQuality = .high
preview.setFillColor(NSColor(calibratedWhite: 0.96, alpha: 1).cgColor)
preview.fill(CGRect(x: 0, y: 0, width: 1920, height: 1320))
for (index, page) in pages.enumerated() {
    let path = directory.appendingPathComponent("\(page.name)-search-3840x2560.png")
    let image = NSImage(contentsOf: path)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let column = index % 2
    let row = index / 2
    preview.draw(image, in: CGRect(x: 20 + column * 950, y: 20 + (1 - row) * 660,
                                   width: 930, height: 620))
}
try write(preview, filename: "preview-search-results-four-options.png")
