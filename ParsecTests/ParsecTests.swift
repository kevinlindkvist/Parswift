//
//  ParsecTests.swift
//  ParsecTests
//
//  Created by Kevin Lindkvist on 1/23/17.
//  Copyright © 2017 lindkvist. All rights reserved.
//

import XCTest
@testable import Parsec

class ParsecTests: XCTestCase {

  /// Asserts that the provided `parser` produces the `expected` value when run on `input`.
  ///
  /// - Parameters:
  ///   - input: The input to the parser.
  ///   - parser: The parser to run on the input.
  ///   - expected: The expected output of the parser.
  ///   - file: The file name of the calling method, used for asserts.
  ///   - line: The line number of the calling method, used for asserts.
  func assert(parsing input: String, with parser: StringParserClosure<String, ()>, produces expected: Either<ParseError, String>, file: StaticString = #file, line: UInt = #line) {
    switch (parse(input: input.characters, with: parser), expected) {
    case let (.left(error), .right(output)):
      XCTFail("Expected \(output), but got: \(error)", file: file, line: line)
    case let (.right(output), .left):
      XCTFail("Expected \(expected), but got: \(output)", file: file, line: line)
    case let (.right(output), .right(expectedOutput)):
      XCTAssertEqual(expectedOutput, String(output), file: file, line: line)
    case let (.left(firstError), .left(secondError)):
      // Currenty only check the location of the error.
      XCTAssertEqual(firstError.position, secondError.position, file: file, line: line)
      break
    }
  }

  func error(at column: Int) -> ParseError {
    return ParseError(position: SourcePosition(name: "", line: 1, column: column), messages: [])
  }

  /// Tests that a valid simple string is parsed correctly.
  func testValidString() {
    assert(parsing: "abc", with: string(string: "abc"), produces: .right("abc"))
  }

  /// Tests that the error returned is at column 1 when no input has been consumed by the parser.
  func testInvalidFirstCharacter() {
    assert(parsing: "abc", with: string(string: "cba"), produces: .left(error(at: 1)))
  }

  /// Tests that the error returned is still at column 1 when no input has been consumed by the parser.
  func testInvalidLastCharacter() {
    assert(parsing: "abc", with: string(string: "abd"), produces: .left(error(at: 1)))
  }

  /// Tests combining two string parsers with no space between them.
  func testSeparateStrings() {
    assert(parsing: "abcdef",
           with: string(string: "abc") >>- { first in string(string: "def") >>- { second in create(x: first+second) }},
           produces: .right("abcdef"))
  }

  /// Tests that the error reporting for two combined parsers returns the correct source position.
  func testSeparateStringsError() {
    assert(parsing: "abceef",
           with: string(string: "abc") >>- { first in string(string: "def") >>- { second in create(x: first+second) }},
           produces: .left(error(at: 4)))
  }

}
