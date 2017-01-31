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

extension SourcePosition: Equatable {

  public static func ==(lhs: SourcePosition, rhs: SourcePosition) -> Bool {
    return lhs.line == rhs.line && lhs.column == rhs.column
  }

}

public func +(left: SourcePosition, right: Character) -> SourcePosition {
  return left.add(character: right)
}
