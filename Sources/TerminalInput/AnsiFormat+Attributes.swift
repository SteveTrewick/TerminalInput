import Foundation

extension TerminalInput.AnsiFormat {

  public struct Attributes : Equatable {

    public var isReset       : Bool
    public var isBold        : Bool
    public var isFaint       : Bool
    public var isItalic      : Bool
    public var isUnderlined  : Bool
    public var isInverse     : Bool
    public var foreground    : Color?
    public var background    : Color?

    internal var didReset            : Bool
    internal var boldSpecified       : Bool
    internal var faintSpecified      : Bool
    internal var italicSpecified     : Bool
    internal var underlinedSpecified : Bool
    internal var inverseSpecified    : Bool
    internal var foregroundSpecified : Bool
    internal var backgroundSpecified : Bool

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

    public enum Color : Equatable {
      case standard(StandardColor)
      case bright(StandardColor)
      case palette(UInt8)
      case rgb(red: UInt8, green: UInt8, blue: UInt8)
    }

  }

}
