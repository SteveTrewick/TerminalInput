import Foundation

extension TerminalInput.AnsiFormat {

  /// Describes the stylistic effects that an SGR sequence requests.  Each flag
  /// mirrors an aspect of the way text can be drawn on screen, such as boldness
  /// or foreground colour.
  public struct Attributes : Equatable {

    /// Flags that describe stylistic effects such as bold, underline, or reset.
    public var formats      : Set<Format>
    /// Optional foreground colour requested by the sequence.
    public var foreground   : Color?
    /// Optional background colour requested by the sequence.
    public var background   : Color?

    /// Internal bookkeeping so that the parser can tell whether a property was
    /// explicitly set or merely inherited from previous state.
    internal var specified   : Set<SpecifiedAttribute>

    /// Boolean-style flags expressed as a set so that styles can be added and
    /// removed without tracking individual booleans.
    public enum Format : Hashable {
      case isReset
      case isBold
      case isFaint
      case isItalic
      case isUnderlined
      case isInverse
    }

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
    public init ( formats: Set<Format> = [],
                  foreground: Color? = nil,
                  background: Color? = nil ) {
      self.formats             = formats
      self.foreground          = foreground
      self.background          = background
      self.specified           = []
      if formats.contains(.isReset)      { mark(.reset) }
      if formats.contains(.isBold)       { mark(.bold) }
      if formats.contains(.isFaint)      { mark(.faint) }
      if formats.contains(.isItalic)     { mark(.italic) }
      if formats.contains(.isUnderlined) { mark(.underlined) }
      if formats.contains(.isInverse)    { mark(.inverse) }
      if foreground   != nil { mark(.foreground) }
      if background   != nil { mark(.background) }
    }

    internal mutating func mark ( _ attribute: SpecifiedAttribute ) {
      specified.insert(attribute)
    }

    internal mutating func unmark ( _ attribute: SpecifiedAttribute ) {
      specified.remove(attribute)
    }

    internal mutating func clearMarks () {
      specified.removeAll()
    }

    internal func isSpecified ( _ attribute: SpecifiedAttribute ) -> Bool {
      return specified.contains(attribute)
    }

    /// Equality respects only the user-visible aspects so that different
    /// bookkeeping states compare as identical when they lead to the same
    /// visual outcome.
    public static func == ( lhs: Attributes, rhs: Attributes ) -> Bool {
      return lhs.formats     == rhs.formats
          && lhs.foreground   == rhs.foreground
          && lhs.background   == rhs.background
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
