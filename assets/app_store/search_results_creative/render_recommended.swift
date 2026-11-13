import AppKit
import CoreText
import Foundation

let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let sourceDirectory = directory.deletingLastPathComponent()
    .appendingPathComponent("portrait_screenshots/source", isDirectory: true)
let screenshot = NSImage(contentsOf: sourceDirectory.appendingPathComponent("03-conversation-feedback.png"))!
    .cgImage(forProposedRect: nil, context: nil, hints: nil)!
let screenCrop = screenshot.cropping(to: CGRect(x: 0, y: 400, width: 1206, height: 930))!
let leafImage = NSImage(contentsOf: sourceDirectory.appendingPathComponent("tomato_leaf.png"))!
    .cgImage(forProposedRect: nil, context: nil, hints: nil)!
let leaf = leafImage.cropping(to: CGRect(x: 260, y: 95, width: 700, height: 450))!
let red = NSColor(srgbRed: 0.93, green: 0.25, blue: 0.16, alpha: 1).cgColor

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

func draw(_ context: CGContext) {
    // Apple Search results 3840 × 2560px의 중앙 2168 × 1030px 안전 영역.
    let canvasHeight: CGFloat = 2560
    let leafFrame = CGRect(x: 1205, y: canvasHeight - 810 - 218,
                           width: 340, height: 218)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -5), blur: 14,
                      color: NSColor.white.withAlphaComponent(0.48).cgColor)
    context.draw(leaf, in: leafFrame)
    context.restoreGState()

    let headlines = ["AI와 영어 대화", "문법 피드백까지"]
    for (index, text) in headlines.enumerated() {
        var fontSize: CGFloat = 158
        var line: CTLine!
        repeat {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
                .foregroundColor: NSColor.white.cgColor,
            ]
            line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            if CTLineGetTypographicBounds(line, nil, nil, nil) <= 1040 { break }
            fontSize -= 2
        } while fontSize >= 100
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        context.textPosition = CGPoint(x: 1375 - lineWidth / 2,
                                       y: canvasHeight - 1120 - 158 - CGFloat(index) * 180)
        CTLineDraw(line, context)
    }

    let panelHeight: CGFloat = 1100 * 930 / 1206
    let panel = CGRect(x: 1900, y: canvasHeight - 850 - panelHeight,
                       width: 1100, height: panelHeight)
    let path = CGPath(roundedRect: panel, cornerWidth: 58, cornerHeight: 58, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: -18, height: -14), blur: 50,
                      color: NSColor.black.withAlphaComponent(0.28).cgColor)
    context.setFillColor(NSColor.white.cgColor)
    context.addPath(path)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(path)
    context.clip()
    context.draw(screenCrop, in: panel)
    context.restoreGState()

    context.setStrokeColor(NSColor.black.withAlphaComponent(0.12).cgColor)
    context.setLineWidth(4)
    context.addPath(path)
    context.strokePath()
}

func save(_ context: CGContext, filename: String) throws {
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    let png = bitmap.representation(using: .png, properties: [:])!
    try png.write(to: directory.appendingPathComponent(filename))
}

let large = makeContext(width: 3840, height: 2560)
draw(large)
try save(large, filename: "tomatalk-search-recommended-3840x2560.png")

let small = makeContext(width: 1920, height: 1280)
small.scaleBy(x: 0.5, y: 0.5)
draw(small)
try save(small, filename: "tomatalk-search-recommended-1920x1280.png")
