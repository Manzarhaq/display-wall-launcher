import Foundation
import CoreGraphics

enum DisplayLayout {
    static func bounds(_ frames: [CGRect]) throws -> CGRect {
        guard (1...2).contains(frames.count), frames.allSatisfy({ $0.width > 0 && $0.height > 0 }) else {
            throw DisplayError.message("Select one display, or two adjacent displays.")
        }
        if frames.count == 2 {
            let sorted = frames.sorted { $0.minX < $1.minX }
            let a = sorted[0], b = sorted[1]
            guard abs(a.maxX - b.minX) < 2, abs(a.minY - b.minY) < 2, abs(a.height - b.height) < 2 else {
                throw DisplayError.message("Arrange the two displays side by side with equal scaled heights and aligned edges in System Settings → Displays. The app keeps one continuous canvas without gaps or cropping.")
            }
        }
        return frames.dropFirst().reduce(frames[0]) { $0.union($1) }
    }
}
enum DisplayError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
