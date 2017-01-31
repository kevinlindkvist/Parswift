import Foundation

/// State encapsulates information relevant to the current parse operation.
public struct State<Input: Collection, UserState> {
  /// The remaining input.
  let input: Input
  /// The current user state.
  let userState: UserState
  /// The current position of the parser in the input.
  let position: SourcePosition
}
