import Foundation
import XCStringsCLI

@main
@available(macOS 13.0, *)
struct XCatalogMain {
    static func main() async throws {
        await XCStringsCLI.main()
    }
}
