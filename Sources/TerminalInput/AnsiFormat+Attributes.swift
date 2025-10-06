import Foundation

extension TerminalInput.AnsiFormat {

  /// Describes the stylistic effects that an SGR sequence requests.  Each flag
  /// mirrors an aspect of the way text can be drawn on screen, such as boldness
  /// or foreground colour.
  public struct Attributes : Equatable {

    /// Optional foreground colour requested by the sequence.
    public var foreground        : Color?
    /// Optional background colour requested by the sequence.
    public var background        : Color?

    /// Internal bookkeeping so that the parser can tell whether a property was
    /// explicitly set or merely inherited from previous state.
    internal var attributeStates : [SpecifiedAttribute: Bool]

    internal enum SpecifiedAttribute : Hashable {
      case reset
      case bold
      case faint
      case italic
      case underlined
      case inverse
      case foreground
      case background
    }

    /// Initialiser with defaults that match the “plain text” look.
    public init ( foreground: Color? = nil,
                  background: Color? = nil ) {
      self.foreground        = foreground
      self.background        = background
      self.attributeStates   = [:]
      if foreground != nil { setAttribute(.foreground, enabled: true) }
      if background != nil { setAttribute(.background, enabled: true) }
    }

    internal mutating func setAttribute ( _ attribute: SpecifiedAttribute, enabled: Bool ) {
      attributeStates[attribute] = enabled
    }

    internal mutating func clearAttribute ( _ attribute: SpecifiedAttribute ) {
      attributeStates.removeValue(forKey: attribute)
    }

    internal mutating func clearMarks () {
      attributeStates.removeAll()
    }

    internal func isSpecified ( _ attribute: SpecifiedAttribute ) -> Bool {
      return attributeStates[attribute] != nil
    }

    internal func isAttributeEnabled ( _ attribute: SpecifiedAttribute ) -> Bool? {
      return attributeStates[attribute]
    }

    /// Equality respects only the user-visible aspects so that different
    /// bookkeeping states compare as identical when they lead to the same
    /// visual outcome.
    public static func == ( lhs: Attributes, rhs: Attributes ) -> Bool {
      return lhs.attributeStates == rhs.attributeStates
          && lhs.foreground      == rhs.foreground
          && lhs.background      == rhs.background
    }

    /// The eight classic colours defined by the ANSI standard.
    public enum StandardColor : Int, Equatable {
      case black = 0
      case red
      case green
      case yellow
      case blue
      case magenta
      case cyan
      case white
    }

    /// All possible ways the terminal can express colour.
    public enum Color : Equatable {
      /// One of the eight standard colours.
      case standard(StandardColor)
      /// One of the eight “bright” variants, sometimes called high intensity.
      case bright(StandardColor)
      /// An index into the 256-colour lookup table that modern terminals offer.
      case palette(UInt8)
      /// A true-colour red/green/blue triple.
      case rgb(red: UInt8, green: UInt8, blue: UInt8)
    }

  }

}
