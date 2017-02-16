import Foundation

/// A parser is a function that consumes input and produces a response object.
///
/// `Output` is the type of the output.
/// `Input` is a collection that represents the input (say, String.CharacterView).
/// `UserState` is any arbitrary type that can be used to track state during parsing.
public typealias Parser<Output, Input: Collection, UserState> = (State<Input, UserState>) -> Consumed<Output, Input, UserState>
public typealias ParserClosure<Output, Input: Collection, UserState> = () -> (State<Input, UserState>) -> Consumed<Output, Input, UserState>

// MARK: Operators

precedencegroup BindPrecedence {
  associativity: left
  higherThan: ChoicePrecedence
}

precedencegroup ChoicePrecedence {
  associativity: right
  higherThan: LabelPrecedence
}

precedencegroup LabelPrecedence {
}

/// The bind operator.
/// `A` is the output type of the left hand side, `B` is the output type of the right hand side.
/// `C` is the input type, and `U` is the user state.
infix operator >>- : BindPrecedence
public func >>-<A, B, C: Collection, U>(parser: @escaping ParserClosure<A, C, U>, f: @escaping (A) -> ParserClosure<B, C, U>) -> ParserClosure<B, C, U> {
  return bind(parser: parser, f: f)
}

/// First parses the input using the left hand side, discards the output, and then parses the remaining input using the right hand side.
infix operator *> : BindPrecedence
public func *><A, B, C: Collection, U>(parser: @escaping ParserClosure<A, C, U>, f: @escaping ParserClosure<B, C, U>) -> ParserClosure<B, C, U> {
  return parser >>- { _ in f }
}

/// First parses the input using the left hand side, saves the output, and then parses the remaining input using the right hand side and discards the output.
infix operator <* : BindPrecedence
public func <*<A, B, C: Collection, U>(parser: @escaping ParserClosure<A, C, U>, f: @escaping ParserClosure<B, C, U>) -> ParserClosure<A, C, U> {
  return parser >>- { x in f *> pure(x) }
}

/// Lifts an output value of the parser to a ParserClosure of that type.
func pure<Output, Input: Collection, UserState>(_ x: Output) -> ParserClosure<Output, Input, UserState> {
  return parserReturn(x)
}

func parserReturn<Output, Input: Collection, UserState>(_ x: Output) -> ParserClosure<Output, Input, UserState> {
  return {{ state in .empty(.some(x, state, unknownError(state: state))) }}
}

public func create<Output, Input: Collection, UserState> (x: Output) -> ParserClosure<Output, Input, UserState> {
  return parserReturn(x)
}

/// The bind operator implementation.
/// `A` is the output type of the left hand side, `B` is the output type of the right hand side.
/// `C` is the input type, and `U` is the user state.
public func bind<A, B, C: Collection, U>(parser: @escaping ParserClosure<A, C, U>, f: @escaping (A) -> ParserClosure<B, C, U>) -> ParserClosure<B, C, U> {
  return {
    { state in
      switch parser()(state) {
      case let .empty(firstReply):
        switch firstReply {
        case let .error(error): return .empty(.error(error))
        case let .some(output, input, firstReply):
          switch f(output)()(input) {
          case let .empty(.error(secondError)):
            return .empty(.error(merge(firstError: firstReply, secondError: secondError)))
          case let .empty(.some(some,  _, secondReply)):
            return .empty(.some(some, input, merge(firstError: firstReply, secondError: secondReply)))
          case let .consumed(secondReply):
            switch secondReply {
            case let .error(secondError):
              return .consumed(.error(merge(firstError: firstReply, secondError: secondError)))
            case let .some(some, rest, secondReply):
              return .consumed(.some(some, rest, merge(firstError: firstReply, secondError: secondReply)))
            }
          }
        }
      case let .consumed(firstReply):
        let result: Reply<B, C, U> = {
          switch firstReply {
          case let .error(error):
            return .error(error)
          case let .some(output, input, firstReply):
            switch f(output)()(input) {
            case let .empty(.error(secondReply)):
              return .error(merge(firstError: firstReply, secondError: secondReply))
            case let .empty(.some(output, input, secondReply)):
              return .some(output, input, merge(firstError: firstReply, secondError: secondReply))
            case let .consumed(secondReply):
              return secondReply
            }
          }
        }()
        return .consumed(result)
      }
    }
  }
}

/// Returns a parser closure that immediately fails with the given message.
public func fail<Output, Input: Collection, UserState>(message: String) -> ParserClosure<Output, Input, UserState> {
  return {{ state in .empty(.error(ParseError(position: state.position, messages: [.message(message)]))) }}
}

/// Parses input using `parser`, and if that fails *without consuming any input*, attempts parsing using otherParser.
public func plus<Output, Input: Collection, UserState>(parser: @escaping ParserClosure<Output, Input, UserState>, otherParser: @escaping ParserClosure<Output, Input, UserState>) -> ParserClosure<Output, Input, UserState> {
  return {{ state in
    switch parser()(state) {
    // If the first parser failed try the second parser.
    case let .empty(.error(firstError)):
      switch otherParser()(state) {
      case let .empty(.error(secondError)):
        return .empty(.error(merge(firstError: firstError, secondError: secondError)))
      case let .empty(.some(output, input, secondMessage)):
        return .empty(.some(output, input, merge(firstError: firstError, secondError: secondMessage)))
      case let consumed: return consumed
      }
    // If the first parser did not consum any input, try the second parser.
    case let .empty(.some(output, input, firstMessage)):
      switch otherParser()(state) {
      case let .empty(.error(secondError)):
        return .empty(.some(output, input, merge(firstError: firstMessage, secondError: secondError)))
      case let .empty(.some(_, _, secondMessage)):
        return .empty(.some(output, input, merge(firstError: firstMessage, secondError: secondMessage)))
      case let consumed: return consumed
      }
    case let consumed: return consumed
    }
    }}
}

public func parserZero<Output, Input: Collection, UserState>() -> Parser<Output, Input, UserState> {
  return { state in
    .empty(.error(unknownError(state: state)))
  }
}

/// Parses input using `parser`, and if that fails *without consuming input*, replaces the error message with `message`. This is useful to return meaningful error messages.
infix operator <?> : LabelPrecedence
public func <?><Output, Input: Collection, UserState>(parser: @escaping ParserClosure<Output, Input, UserState>, message: String) -> ParserClosure<Output, Input, UserState> {
  return label(parser: parser, message: message)
}

/// Parses input using `parser`, and if that fails *without consuming input*, replaces the error message with `message`. This is useful to return meaningful error messages.
public func label<Output, Input: Collection, UserState>(parser: @escaping ParserClosure<Output, Input, UserState>, message: String) -> ParserClosure<Output, Input, UserState> {
  return labels(parser: parser, messages: [message])
}

/// Parses input using `parser`, and if that fails *without consuming input*, replaces the error message with `messages`. This is useful to return meaningful error messages.
public func labels<Output, Input: Collection, UserState>(parser: @escaping ParserClosure<Output, Input, UserState>, messages: [String]) -> ParserClosure<Output, Input, UserState> {
  return {{ state in
    switch parser()(state) {
    case let .empty(.error(error)): return .empty(.error(setExpect(messages: messages, error: error)))
    case let .empty(.some(output, input, message)): return .empty(.some(output, input, setExpect(messages: messages, error: message)))
    case let other: return other
    }
    }}
}

/// Sets `error.messages` to `.expected` error messages with the values provided in `messages`.
public func setExpect(messages: [String], error: ParseError) -> ParseError {
  return ParseError(position: error.position, messages: messages.map { .expected($0) })
}

/// Parses the input using `parser` and if that fails *without consuming any input*, attempts to parse the input with `otherParser`.
infix operator <|> : ChoicePrecedence
public func <|> <Output, Input: Collection, UserState> (parser: @escaping ParserClosure<Output, Input, UserState>, otherParser: @escaping ParserClosure<Output, Input, UserState>) -> ParserClosure<Output, Input, UserState> {
  return plus(parser: parser, otherParser: otherParser)
}

/// Parses the input and pretends like no input was consumed if the parser fails.
public func attempt<Output, Input: Collection, UserState> (parser: @escaping ParserClosure<Output, Input, UserState>) -> ParserClosure<Output, Input, UserState> {
  return {{ state in
    switch parser()(state) {
    case let .consumed(reply):
      switch reply {
      case let .error(message): return .empty(.error(message))
      default: return .consumed(reply)
      }
    case let other: return other
    }
    }}
}

public func token<Output, Input: Collection, UserState>(showToken: @escaping (Input.Iterator.Element) -> String, tokenPosition: @escaping (Input.Iterator.Element) -> SourcePosition, test: @escaping (Input.Iterator.Element) -> Output?) -> ParserClosure<Output, Input, UserState> where Input.SubSequence == Input {
  let getNextPosition: (SourcePosition, Input.Iterator.Element, Input) -> SourcePosition = { _, current, rest in
    if let next = rest.first {
      return tokenPosition(next)
    } else {
      return tokenPosition(current)
    }
  }
  return token(showToken: showToken, nextTokenPosition: getNextPosition, test: test)
}

public func token<Output, Input: Collection, UserState>(showToken: @escaping (Input.Iterator.Element) -> String,
                  nextTokenPosition: @escaping (SourcePosition, Input.Iterator.Element, Input) -> SourcePosition,
                  test: @escaping (Input.Iterator.Element) -> Output?)
  -> ParserClosure<Output, Input, UserState> where Input.SubSequence == Input {
    return {{ (state: State<Input, UserState>) in
      if let head = state.input.first, let result = test(head) {
        let tail: Input = state.input.dropFirst()
        let adjustedPosition: SourcePosition = nextTokenPosition(state.position, head, tail)
        let adjustedState: State<Input, UserState> = State(input: tail, userState: state.userState, position: adjustedPosition)
        return .consumed(.some(result, adjustedState, unknownError(state: adjustedState)))
      } else if let head = state.input.first {
        return .empty(.error(ParseError(position: state.position, messages: [.systemUnexpected(showToken(head))])))
      } else {
        return .empty(.error(ParseError(position: state.position, messages: [.systemUnexpected("")])))
      }
      }}
}

public func tokens<Input: Collection, UserState> (showTokens: @escaping ([Input.Iterator.Element]) -> String, nextTokenPosition: @escaping (SourcePosition, [Input.Iterator.Element]) -> SourcePosition, tokens: [Input.Iterator.Element]) -> ParserClosure<[Input.Iterator.Element], Input, UserState>
  where Input.Iterator.Element: Equatable, Input.SubSequence == Input
{
  if let token = tokens.first {
    let restOfTokens = tokens.dropFirst()
    return {{ state in
      let errorEndOfFile = ParseError(position: state.position, messages: [.systemUnexpected(""), .expected(showTokens(tokens))])
      let errorExpected = { x in ParseError(position: state.position, messages: [.systemUnexpected(showTokens([x])), .expected(showTokens(tokens))]) }

      func walk(restOfTokens: ArraySlice<Input.Iterator.Element>, restOfInput: Input) -> Consumed<[Input.Iterator.Element], Input, UserState> {
        if let firstToken = restOfTokens.first {
          let tailOfTokens = restOfTokens.dropFirst()
          if let firstInput = restOfInput.first {
            let tailOfInput = restOfInput.dropFirst()
            if firstToken == firstInput {
              return walk(restOfTokens: tailOfTokens, restOfInput: tailOfInput)
            } else {
              return .consumed(.error(errorExpected(firstInput)))
            }
          } else {
            return .consumed(.error(errorEndOfFile))
          }
        } else {
          let adjustedPosition = nextTokenPosition(state.position, tokens)
          let adjustedState = State(input: restOfInput, userState: state.userState, position: adjustedPosition)
          return .consumed(.some(tokens, adjustedState, unknownError(state: adjustedState)))
        }
      }

      if let firstInput = state.input.first {
        let restOfInput = state.input.dropFirst()
        if token == firstInput { return walk(restOfTokens: restOfTokens, restOfInput: restOfInput) }
        else { return .empty(.error(errorExpected(firstInput))) }
      } else {
        return .empty(.error(errorEndOfFile))
      }
      }}
  } else {
    return {{ state in .empty(.some([], state, unknownError(state: state))) }}
  }
}


public func many<Output, Input: Collection, UserState>(accumulator: @escaping (Output, [Output]) -> [Output], parser: @escaping ParserClosure<Output, Input, UserState>) -> ParserClosure<[Output], Input, UserState> {
  func walk (xs: [Output], x: Output, state: State<Input, UserState>) -> Consumed<[Output], Input, UserState> {
    switch parser()(state) {
    case let .consumed(reply):
      switch reply {
      case let .error(error): return .consumed(.error(error))
      case let .some(output, state, _): return walk(xs: accumulator(x, xs), x: output, state: state)
      }
    case let .empty(reply):
      switch reply {
      case let .error(error): return .consumed(.some(accumulator(x, xs), state, error))
      case .some: fatalError()
      }
    }
  }

  return {{ state in
    switch parser()(state) {
    case let .consumed(reply):
      switch reply {
      case let .error(error): return .consumed(.error(error))
      case let .some(output, state, _): return walk(xs: [], x: output, state: state)
      }
    case let .empty(reply):
      switch reply {
      case let .error(error): return .empty(.some([], state, error))
      case .some: fatalError()
      }
    }
    }}
}

public func many<Output, Input: Collection, UserState>(parser: @escaping ParserClosure<Output, Input, UserState>) -> ParserClosure<[Output], Input, UserState> {
  return many(accumulator: append, parser: parser)
}

public func many1<Output, Input: Collection, UserState> (parser: @escaping ParserClosure<Output, Input, UserState>) -> ParserClosure<[Output], Input, UserState> {
  return parser >>- { x in
    many(parser: parser) >>- { xs in
      var r = [x]
      r.append(contentsOf: xs)
      return create(x: r)
    }
  }
}

public func append<A>(_ next: A, _ list: [A]) -> [A] {
  return list + [next]
}

public func skipMany<Output, Input: Collection, UserState>(parser: @escaping ParserClosure<Output, Input, UserState>) -> ParserClosure<(), Input, UserState> {
  return many(accumulator: { _, _ in []} , parser: parser) *> create(x: ())
}

public func add<Output, Input: Collection, UserState>(parser: @escaping ParserClosure<Output, Input, UserState>, to otherParser: @escaping ParserClosure<Output, Input, UserState>) -> ParserClosure<Output, Input, UserState> {
  return {{ state in
    switch parser()(state) {
    case let .empty(.error(firstMessage)):
      switch otherParser()(state) {
      case let .empty(.error(secondMessage)): return .empty(.error(merge(firstError: firstMessage, secondError: secondMessage)))
      case let .empty(.some(x, input, secondMessage)): return .empty(.some(x, input, merge(firstError: firstMessage, secondError: secondMessage)))
      case let consumed: return consumed
      }
    case let .empty(.some(x, input, firstMessage)):
      switch otherParser()(state) {
      case let .empty(.error(secondMessage)): return .empty(.some(x, input, merge(firstError: firstMessage, secondError: secondMessage)))
      case let .empty(.some(_, _, secondMessage)): return .empty(.some(x, input, merge(firstError: firstMessage, secondError: secondMessage)))
      case let consumed: return consumed
      }
    case let consumed: return consumed
    }
    }}
}

// MARK: Running Parsers

public func parse<Output, Input: Collection, UserState>(input: Input, with parser: ParserClosure<Output, Input, UserState>, userState: UserState, fileName: String) -> Either<ParseError, Output> {
  switch parser()(State(input: input, userState: userState, position: SourcePosition(name: fileName, line: 1, column: 1))) {
  case let .consumed(reply):
    switch reply {
    case let .some(x, _, _): return .right(x)
    case let .error(error): return .left(error)
    }
  case let .empty(reply):
    switch reply {
    case let .some(x, _, _): return .right(x)
    case let .error(error): return .left(error)
    }
  }
}

public func parse<Output, Input: Collection, UserState>(input: Input, with parser: ParserClosure<Output, Input, UserState>, userState: UserState, fileName: String) -> Either<ParseError, (Output, UserState)> {
  switch parser()(State(input: input, userState: userState, position: SourcePosition(name: fileName, line: 1, column: 1))) {
  case let .consumed(reply):
    switch reply {
    case let .some(x, state, _): return .right((x, state.userState))
    case let .error(error): return .left(error)
    }
  case let .empty(reply):
    switch reply {
    case let .some(x, state, _): return .right((x, state.userState))
    case let .error(error): return .left(error)
    }
  }
}

public func parse<Output, Input: Collection> (input: Input, with parser: ParserClosure<Output, Input, ()>) -> Either<ParseError, Output> {
  return parse(input: input, with: parser, userState: (), fileName: "")
}

// MARK: Parser State

public func parserPosition<Input: Collection, UserState>() -> Parser<SourcePosition, Input, UserState> {
  return (parserState >>- { state in create(x: state.position) })()
}

public func parserInput<Input: Collection, UserState>() -> Parser<Input, Input, UserState> {
  return (parserState >>- { state in create(x: state.input) })()
}

public func parserState<Input: Collection, UserState>() -> Parser<State<Input, UserState>, Input, UserState> {
  return (updateParserState { state in state })()
}

public func userState<Input: Collection, UserState> () -> Parser<UserState, Input, UserState> {
  return (parserState >>- { state in create(x: state.userState)})()
}

public func updateParserState<Input: Collection, UserState>(f: @escaping (State<Input, UserState>) -> State<Input, UserState>) -> ParserClosure<State<Input, UserState>, Input, UserState> {
  return {{ state in
    let newState = f(state)
    return .empty(.some(newState, newState, unknownError(state: newState)))
    }}
}

public func modifyState<Input: Collection, UserState>(f: @escaping (UserState) -> UserState) -> ParserClosure<(), Input, UserState> {
  return updateParserState { state in State(input: state.input, userState: f(state.userState), position: state.position) } *> create(x: ())
}

