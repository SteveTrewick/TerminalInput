import Foundation

extension TerminalInput.AnsiFormat {

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

  public struct AttributeParser {

    public init () { }

    public func parse ( attributes: Attributes ) -> [Attribute] {
      var result : [Attribute] = []
      if attributes.didReset || attributes.isReset {
        result.append(.reset)
      }
      if attributes.boldSpecified {
        result.append(.bold(attributes.isBold))
      }
      if attributes.faintSpecified {
        result.append(.faint(attributes.isFaint))
      }
      if attributes.italicSpecified {
        result.append(.italic(attributes.isItalic))
      }
      if attributes.underlinedSpecified {
        result.append(.underlined(attributes.isUnderlined))
      }
      if attributes.inverseSpecified {
        result.append(.inverse(attributes.isInverse))
      }
      if attributes.foregroundSpecified, let foreground = attributes.foreground {
        result.append(.foreground(foreground))
      }
      if attributes.backgroundSpecified, let background = attributes.background {
        result.append(.background(background))
      }
      return result
    }

  }

}
