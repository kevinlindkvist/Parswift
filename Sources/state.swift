import Foundation

/// State encapsulates information relevant to the current parse operation.
public struct State<Input: Collection, UserState> {
  /// The remaining input.
  public let input: Input
  /// The current user state.
  public let userState: UserState
  /// The current position of the parser in the input.
  public let position: SourcePosition

  public init(input: Input, userState: UserState, position: SourcePosition) {
    self.input = input
    self.userState = userState
    self.position = position
  }
}
