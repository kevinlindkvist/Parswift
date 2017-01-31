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
    return oper >>- { f in
      parser >>- { y in
        rest(x: f(x, y))
      }
      } <|> create(x: x)
  }
  return parser >>- rest
}
