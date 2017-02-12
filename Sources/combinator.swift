import Foundation

public func separate<Output, Input: Collection, UserState, Separator>(parser: @escaping ParserClosure<Output, Input, UserState>, by: @escaping ParserClosure<Separator, Input, UserState>) -> ParserClosure<[Output], Input, UserState> {
  return separate(parser: parser, byAtLeastOne: by) <|> create(x: [])
}

public func separate<Output, Input: Collection, UserState, Separator>(parser: @escaping ParserClosure<Output, Input, UserState>, byAtLeastOne: @escaping ParserClosure<Separator, Input, UserState>) -> ParserClosure<[Output], Input, UserState> {
  return parser >>- { output in
    many(parser: byAtLeastOne *> parser) >>- { outputs in
      return create(x: [output] + outputs)
    }
  }
}

public func chainl<Output, Input: Collection, UserState>(parser: @escaping ParserClosure<Output, Input, UserState>, oper: @escaping ParserClosure<(Output, Output) -> Output, Input, UserState>, x: Output) -> ParserClosure<Output, Input, UserState> {
  return chainl1(parser: parser, oper: oper) <|> create(x: x)
}

public func chainl1<Output, Input: Collection, UserState>(parser: @escaping ParserClosure<Output, Input, UserState>, oper: @escaping ParserClosure<(Output, Output) -> Output, Input, UserState>) -> ParserClosure<Output, Input, UserState> {
  func rest(x: Output) -> ParserClosure<Output, Input, UserState> {
    return attempt(parser: oper >>- { f in
      parser >>- { y in
        rest(x: f(x, y))
      }
      })
      <|> create(x: x)
  }
  return parser >>- rest
}

public func unexpected<Output, Input: Collection, UserState> (message: String) -> ParserClosure<Output, Input, UserState> {
  return {{ state in
    .empty(.error(ParseError(position: state.position, messages: [.unexpected(message)])))
    }}
}

public func any<Input: Collection, UserState>() -> Parser<Input.Iterator.Element, Input, UserState>
  where Input.SubSequence == Input {
    return (token(showToken: { String(describing: $0) }, nextTokenPosition: { pos, _, _ in pos }, test: { $0 }))()
}

public func endOfInput<Input: Collection, UserState>() -> Parser<(), Input, UserState>
  where Input.SubSequence == Input {
    return (notFollowed(by: any) <?> "end of input")()
}

public func notFollowed<Output, Input: Collection, UserState>(by parser: @escaping ParserClosure<Output, Input, UserState>) -> ParserClosure<(), Input, UserState> {
  return attempt(parser: parser) >>- { c in unexpected(message: String(describing: c)) }
    <|> create(x: ())
}
