import XCTest
@testable import Parswift

class ParswiftTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(Parswift().text, "Hello, World!")
    }


    static var allTests : [(String, (ParswiftTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
