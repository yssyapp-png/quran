import Foundation
import Vision
import ImageIO

guard CommandLine.arguments.count == 2 else {
  fputs("Usage: ocr_arabic.swift <image-path>\n", stderr)
  exit(64)
}

let imagePath = CommandLine.arguments[1]
let imageUrl = URL(fileURLWithPath: imagePath)

guard let source = CGImageSourceCreateWithURL(imageUrl as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
  fputs("Unable to read image: \(imagePath)\n", stderr)
  exit(65)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["ar-SA"]
request.usesLanguageCorrection = true

let handler = VNImageRequestHandler(cgImage: image, options: [:])
do {
  try handler.perform([request])
  let lines = (request.results ?? [])
    .sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
    .compactMap { $0.topCandidates(1).first?.string }
  print(lines.joined(separator: "\n"))
} catch {
  fputs("Arabic OCR failed: \(error)\n", stderr)
  exit(1)
}
