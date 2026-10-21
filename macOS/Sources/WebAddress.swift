import Foundation

enum WebAddress {
    static func parse(_ address: String) throws -> URL {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host?.isEmpty == false, url.user == nil, url.password == nil else {
            throw DisplayError.message("Enter a complete http:// or https:// web address without embedded credentials.")
        }
        return url
    }
}
