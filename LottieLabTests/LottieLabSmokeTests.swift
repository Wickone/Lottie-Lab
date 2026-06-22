import XCTest
@testable import LottieLab

final class LottieLabSmokeTests: XCTestCase {
    func testContentViewCanBeCreated() {
        XCTAssertNotNil(ContentView())
    }

    func testDocumentsDirectoryIsAFileURL() {
        XCTAssertTrue(FileManager.documentsDirectory().isFileURL)
    }
}

