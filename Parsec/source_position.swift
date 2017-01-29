//
//  source_position.swift
//  Parsec
//
//  Created by Kevin Lindkvist on 1/28/17.
//  Copyright © 2017 lindkvist. All rights reserved.
//

import Foundation

public struct SourcePosition {
  let name: String
  let line: Int
  let column: Int

  func add(character: Character) -> SourcePosition {
    switch character {
    case "\n": return SourcePosition(name: name, line: line+1, column: column)
    case "\t": return SourcePosition(name: name, line: line, column: column + 8 - ((column - 1) % 8))
    default: return SourcePosition(name: name, line: line, column: column+1)
    }
  }
}

public func +(left: SourcePosition, right: Character) -> SourcePosition {
  return left.add(character: right)
}
