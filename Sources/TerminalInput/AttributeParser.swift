import Foundation

extension TerminalInput.AnsiFormat {

  /// A succinct description of the changes that an SGR sequence applies.  Using
  /// this intermediate representation makes it easy for calling code to switch
  /// over individual effects without needing to inspect several boolean flags.
  public enum Attribute : Equatable {
    case reset
    case bold(Bool)
    case faint(Bool)
    case italic(Bool)
    case underlined(Bool)
    case inverse(Bool)
    case foreground(Attributes.Color)
    case background(Attributes.Color)
  }

  /// Turns the parsed attribute structure into an ordered list of changes.  This
  /// is handy when replaying styles to another output device or when explaining
  /// the meaning of an escape sequence to learners.
  public struct AttributeParser {

    public init () { }

    /// Extracts the individual `Attribute` values that were explicitly provided
    /// by the original escape sequence.  Properties that were not mentioned are
    /// skipped so that the caller sees only the actions that occurred.
    public func parse ( attributes: Attributes ) -> [Attribute] {
      var result : [Attribute] = []
      let order : [Attributes.SpecifiedAttribute] = [
        .reset,
        .bold,
        .faint,
        .italic,
        .underlined,
        .inverse,
        .foreground,
        .background,
      ]
      for attribute in order where attributes.isSpecified(attribute) {
        switch attribute {
          case .reset:
            result.append(.reset)
          case .bold:
            result.append(.bold(attributes.isBold))
          case .faint:
            result.append(.faint(attributes.isFaint))
          case .italic:
            result.append(.italic(attributes.isItalic))
          case .underlined:
            result.append(.underlined(attributes.isUnderlined))
          case .inverse:
            result.append(.inverse(attributes.isInverse))
          case .foreground:
            if let foreground = attributes.foreground {
              result.append(.foreground(foreground))
            }
          case .background:
            if let background = attributes.background {
              result.append(.background(background))
            }
        }
      }
      return result
    }

  }

}
