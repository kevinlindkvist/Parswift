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

  func testParseString() {
    func t() -> StringParserClosure<String, ()> {
      return string(string: "abc")
    }
    parse(test: t(), input: "abc".characters)
  }

}
