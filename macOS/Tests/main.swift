import Foundation
import CoreGraphics

func expect(_ condition: Bool, _ name: String) { precondition(condition, name) }
func rejects(_ name: String, _ body: () throws -> Void) {
    do { try body(); fatalError("Should reject: \(name)") } catch { print("PASS reject \(name)") }
}
let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
let right = CGRect(x: 0, y: 0, width: 1920, height: 1080)
expect(try DisplayLayout.bounds([right, left]) == CGRect(x: -1920, y: 0, width: 3840, height: 1080), "Negative-origin two-display union")
expect(try DisplayLayout.bounds([right]) == right, "Single display")
rejects("empty") { _ = try DisplayLayout.bounds([]) }
rejects("three displays") { _ = try DisplayLayout.bounds([left, right, right]) }
rejects("overlap") { _ = try DisplayLayout.bounds([right, right]) }
rejects("gap") { _ = try DisplayLayout.bounds([left, right.offsetBy(dx: 20, dy: 0)]) }
rejects("unequal heights") { _ = try DisplayLayout.bounds([left, CGRect(x: 0,y: 0,width: 1920,height: 1200)]) }
rejects("vertical offset") { _ = try DisplayLayout.bounds([left, right.offsetBy(dx: 0,dy: 10)]) }
expect(try WebAddress.parse(" https://example.com/wall ").host == "example.com", "HTTPS URL")
for bad in ["", "example.com", "file:///tmp/index.html", "javascript:alert(1)", "https://user:secret@example.com/"] {
    rejects("invalid address") { _ = try WebAddress.parse(bad) }
}
print("PASS: geometry and URL validation")
