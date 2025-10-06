import Foundation

extension TerminalInput.AnsiFormat {

  /// Describes the stylistic effects that an SGR sequence requests.  Each flag
  /// mirrors an aspect of the way text can be drawn on screen, such as boldness
  /// or foreground colour.
  public struct Attributes : Equatable {

    /// Indicates whether the sequence requested a full reset of prior styling.
    public var isReset       : Bool
    /// True when the sequence enables bold text.
    public var isBold        : Bool
    /// True when the sequence enables faint (dim) text.
    public var isFaint       : Bool
    /// True when the sequence enables italic text.
    public var isItalic      : Bool
    /// True when the sequence enables underlined text.
    public var isUnderlined  : Bool
    /// True when foreground and background colours should be swapped.
    public var isInverse     : Bool
    /// Optional foreground colour requested by the sequence.
    public var foreground    : Color?
    /// Optional background colour requested by the sequence.
    public var background    : Color?

    /// Internal bookkeeping so that the parser can tell whether a property was
    /// explicitly set or merely inherited from previous state.
    internal var didReset            : Bool
    internal var boldSpecified       : Bool
    internal var faintSpecified      : Bool
    internal var italicSpecified     : Bool
    internal var underlinedSpecified : Bool
    internal var inverseSpecified    : Bool
    internal var foregroundSpecified : Bool
    internal var backgroundSpecified : Bool

    /// Initialiser with defaults that match the “plain text” look.
    public init ( isReset: Bool = false,
                  isBold: Bool = false,
                  isFaint: Bool = false,
                  isItalic: Bool = false,
                  isUnderlined: Bool = false,
                  isInverse: Bool = false,
                  foreground: Color? = nil,
                  background: Color? = nil ) {
      self.isReset             = isReset
      self.isBold              = isBold
      self.isFaint             = isFaint
      self.isItalic            = isItalic
      self.isUnderlined        = isUnderlined
      self.isInverse           = isInverse
      self.foreground          = foreground
      self.background          = background
      self.didReset            = isReset
      self.boldSpecified       = isBold
      self.faintSpecified      = isFaint
      self.italicSpecified     = isItalic
      self.underlinedSpecified = isUnderlined
      self.inverseSpecified    = isInverse
      self.foregroundSpecified = foreground != nil
      self.backgroundSpecified = background != nil
    }

    /// Equality respects only the user-visible aspects so that different
    /// bookkeeping states compare as identical when they lead to the same
    /// visual outcome.
    public static func == ( lhs: Attributes, rhs: Attributes ) -> Bool {
      return lhs.isReset      == rhs.isReset
          && lhs.isBold       == rhs.isBold
          && lhs.isFaint      == rhs.isFaint
          && lhs.isItalic     == rhs.isItalic
          && lhs.isUnderlined == rhs.isUnderlined
          && lhs.isInverse    == rhs.isInverse
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
