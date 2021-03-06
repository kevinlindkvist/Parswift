import Foundation

public typealias StringParser<Output, UserState> = (State<String.CharacterView, UserState>) -> Consumed<Output, String.CharacterView, ()>
public typealias StringParserClosure<Output, UserState> = () -> (State<String.CharacterView, UserState>) -> Consumed<Output, String.CharacterView, ()>

public func satisfy<Input: Collection, UserState>(f: @escaping (Character) -> Bool) -> ParserClosure<Character, Input, UserState> where Input.SubSequence == Input, Input.Iterator.Element == Character {
  func show(character: Character) -> String {
    return String(character)
  }
  func next(position: SourcePosition, character: Character, characters: Input) -> SourcePosition {
    return position.add(character: character)
  }
  func test(character: Character) -> Character? {
    return f(character) ? character : nil
  }

  return token(showToken: show, nextTokenPosition: next, test: test)
}

public func string<Input: Collection, UserState>(string: String) -> ParserClosure<String, Input, UserState> where Input.SubSequence == Input, Input.Iterator.Element == Character {
  func show(characters: [Character]) -> String {
    return String(characters)
  }
  func next(position: SourcePosition, characters: [Character]) -> SourcePosition {
    return characters.reduce(position, +)
  }

  return tokens(showTokens: show, nextTokenPosition: next, tokens: Array(string.characters)) >>- { characters in
    return create(x: String(characters))
  }
}

public func character<Input: Collection, UserState> (character: Character) -> ParserClosure<Character, Input, UserState> where Input.SubSequence == Input, Input.Iterator.Element == Character {
  return satisfy { x in x == character } <?> String(character)
}

public func spaces<Input: Collection, UserState>() -> Parser<(), Input, UserState> where Input.SubSequence == Input, Input.Iterator.Element == Character {
  return (skipMany(parser: space) <?> "whitespace")()
}

public func space<Input: Collection, UserState>() -> Parser<Character, Input, UserState> where Input.SubSequence == Input, Input.Iterator.Element == Character {
  return (satisfy(f: isSpace) <?> "space")()
}

public func alphanumerics<Input: Collection, UserState>() -> Parser<String, Input, UserState> where Input.SubSequence == Input, Input.Iterator.Element == Character {
  return (many(parser: alphanumeric) >>- { create(x: String($0)) } <?> "alphanumerics")()
}

public func alphanumeric<Input: Collection, UserState>() -> Parser<Character, Input, UserState> where Input.SubSequence == Input, Input.Iterator.Element == Character {
  return satisfy(f: isAlphanumeric)()
}

func isSpace(character: Character) -> Bool {
  let whitespaces = CharacterSet.whitespacesAndNewlines
  return String(character).rangeOfCharacter(from: whitespaces) != nil
}

func isAlphanumeric(character: Character) -> Bool {
  let alphanumerics = CharacterSet.alphanumerics
  return String(character).rangeOfCharacter(from: alphanumerics) != nil
}

public func keyword(identifier: String) -> ParserClosure<String, String.CharacterView, ()> {
  return attempt(parser: spaces *> string(string: identifier) <* spaces)
}
