import Foundation

public enum Consumed<Output, Input: Collection, UserState> {
  case consumed(Reply<Output, Input, UserState>)
  case empty(Reply<Output, Input, UserState>)

  func map<ConvertedOutput>(_ f: @escaping (Output) -> ConvertedOutput) -> Consumed<ConvertedOutput, Input, UserState> {
    switch self {
    case let .consumed(reply): return .consumed(reply.map(f))
    case let .empty(reply): return .empty(reply.map(f))
    }
  }
}

public enum Reply<Output, Input: Collection, UserState> {
  case some(Output, State<Input, UserState>, ParseError)
  case error(ParseError)

  func map<ConvertedOutput>(_ f: @escaping (Output) -> ConvertedOutput) -> Reply<ConvertedOutput, Input, UserState> {
    switch self {
    case let .some(output, state, error): return .some(f(output), state, error)
    case let .error(error): return .error(error)
    }
  }
}

public enum Either<Left, Right> {
  case left(Left)
  case right(Right)
}
