import Foundation


public final class TerminalInput {

  public var dispatch : ( (Result<Token, Error>) -> Void )?

  public enum Error : Swift.Error, Equatable {
    case invalidUTF8(Data)
    case invalidSequence(String)
  }

  public enum Token : Equatable {
    case text(String)
    case control(ControlKey)
    case cursor(CursorKey)
    case function(FunctionKey)
    case meta(MetaKey)
    case response(TerminalResponse)
    case ansi(AnsiFormat)
  }

  public enum ControlKey : Equatable {
    case NULL
    case SOH
    case STX
    case ETX
    case EOT
    case ENQ
    case ACK
    case BEL
    case BACKSPACE
    case TAB
    case LF
    case VT
    case FF
    case RETURN
    case SO
    case SI
    case DLE
    case DC1
    case DC2
    case DC3
    case DC4
    case NAK
    case SYN
    case ETB
    case CAN
    case EM
    case SUB
    case FS
    case GS
    case RS
    case US
    case DEL
  }

  public enum CursorKey : Equatable {
    case up
    case down
    case right
    case left
    case home
    case end
    case pageUp
    case pageDown
  }

  public enum FunctionKey : Equatable {
    case f(Int)
    case insert
    case delete
    case unknown(String)
  }

  public enum MetaKey : Equatable {
    case alt(Character)
    case escape
  }

  public enum TerminalResponse : Equatable {
    case cursorPosition(row: Int, column: Int)
    case deviceAttributes(values: [Int], isPrivate: Bool)
    case statusReport(code: Int)
    case operatingSystemCommand(code: Int, data: String)
    case text(String)
  }

  public struct AnsiFormat : Equatable {

    public let sequence   : String
    public let attributes : Attributes

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
        self.isReset            = isReset
        self.isBold             = isBold
        self.isFaint            = isFaint
        self.isItalic           = isItalic
        self.isUnderlined       = isUnderlined
        self.isInverse          = isInverse
        self.foreground         = foreground
        self.background         = background
        self.didReset           = isReset
        self.boldSpecified      = isBold
        self.faintSpecified     = isFaint
        self.italicSpecified    = isItalic
        self.underlinedSpecified = isUnderlined
        self.inverseSpecified   = isInverse
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

    //TODO: extract this
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

    //TODO: extract this
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

  public init () { }

  public func enqueue ( _ bytes: Data ) {
    buffer.append(bytes)
    processBuffer()
  }

  private var buffer : Data = Data()

  private enum ParseResult {
    case token(Token, Int)
    case needMore
    case failure(Error, Int)
  }

  private func processBuffer () {
    while true {
      let result = parseNextToken()
      switch result {
        case .needMore:
          return
        case .token(let token, let consumed):
          buffer.removeSubrange(0 ..< consumed)
          dispatch?( .success(token) )
        case .failure(let error, let consumed):
          buffer.removeSubrange(0 ..< consumed)
          dispatch?( .failure(error) )
      }
    }
  }

  private func parseNextToken () -> ParseResult {
    guard let first = buffer.first else { return .needMore }
    if let control = parseControl(first) {
      return .token( .control(control), 1 )
    }
    if first == 0x1B {
      return parseEscapeSequence()
    }
    return parseText()
  }

  private func parseControl ( _ byte: UInt8 ) -> ControlKey? {
    switch byte {
      case 0x00 : return .NULL
      case 0x01 : return .SOH
      case 0x02 : return .STX
      case 0x03 : return .ETX
      case 0x04 : return .EOT
      case 0x05 : return .ENQ
      case 0x06 : return .ACK
      case 0x07 : return .BEL
      case 0x08 : return .BACKSPACE
      case 0x09 : return .TAB
      case 0x0A : return .LF
      case 0x0B : return .VT
      case 0x0C : return .FF
      case 0x0D : return .RETURN
      case 0x0E : return .SO
      case 0x0F : return .SI
      case 0x10 : return .DLE
      case 0x11 : return .DC1
      case 0x12 : return .DC2
      case 0x13 : return .DC3
      case 0x14 : return .DC4
      case 0x15 : return .NAK
      case 0x16 : return .SYN
      case 0x17 : return .ETB
      case 0x18 : return .CAN
      case 0x19 : return .EM
      case 0x1A : return .SUB
      case 0x1C : return .FS
      case 0x1D : return .GS
      case 0x1E : return .RS
      case 0x1F : return .US
      case 0x7F : return .DEL
      default   : return nil
    }
  }

  private func parseText () -> ParseResult {
    var index = 0
    while index < buffer.count {
      let byte = buffer[index]
      if byte < 0x20 || byte == 0x1B || byte == 0x7F {
        break
      }
      index += 1
    }

    guard index > 0 else { return .needMore }

    let textData = buffer.prefix(index)
    if let text = String(data: textData, encoding: .utf8) {
      return .token( .text(text), index )
    }

    if index == buffer.count {
      return .needMore
    }

    return .failure( .invalidUTF8(textData), index )
  }

  private func parseEscapeSequence () -> ParseResult {
    guard buffer.count > 1 else { return .token( .meta(.escape), 1 ) }
    let indicator = buffer[1]
    switch indicator {
      case 0x5B : return parseCSISequence()
      case 0x4F : return parseSS3Sequence()
      case 0x5D : return parseOSCSequence()
      default   : return parseMetaSequence()
    }
  }

  private func parseMetaSequence () -> ParseResult {
    guard buffer.count > 1 else { return .needMore }
    let indicator = buffer[1]
    if indicator < 0x20 {
      return .token( .meta(.escape), 1 )
    }
    let length = 2
    let scalar    = UnicodeScalar(indicator)
    let character = Character(scalar)
    return .token( .meta(.alt(character)), length )
  }

  private func parseCSISequence () -> ParseResult {
    guard let finalIndex = indexOfFinalByte(startingAt: 2) else { return .needMore }
    let finalByte     = buffer[finalIndex]
    let parameterData = buffer[2 ..< finalIndex]
    let sequenceData  = buffer[0 ... finalIndex]
    let sequence      = String(decoding: sequenceData, as: UTF8.self)
    let parameter     = String(decoding: parameterData, as: UTF8.self)

    switch UnicodeScalar(finalByte) {
      case "A":
        return .token( .cursor(.up), finalIndex + 1 )
      case "B":
        return .token( .cursor(.down), finalIndex + 1 )
      case "C":
        return .token( .cursor(.right), finalIndex + 1 )
      case "D":
        return .token( .cursor(.left), finalIndex + 1 )
      case "H":
        return .token( .cursor(.home), finalIndex + 1 )
      case "F":
        return .token( .cursor(.end), finalIndex + 1 )
      case "m":
        let values = parameter.split(separator: ";").compactMap { Int($0) }
        let attributes = parseSGR(values: values)
        return .token( .ansi(AnsiFormat(sequence: sequence, attributes: attributes)), finalIndex + 1 )
      case "R":
        let components = parameter.split(separator: ";").compactMap { Int($0) }
        guard components.count == 2 else {
          return .failure( .invalidSequence(sequence), finalIndex + 1 )
        }
        return .token( .response(.cursorPosition(row: components[0], column: components[1])), finalIndex + 1 )
      case "c":
        let isPrivate = parameter.first == ">"
        let trimmed   = isPrivate ? String(parameter.dropFirst()) : parameter
        let values    = trimmed.split(separator: ";").compactMap { Int($0) }
        return .token( .response(.deviceAttributes(values: values, isPrivate: isPrivate)), finalIndex + 1 )
      case "n":
        guard let code = Int(parameter) else {
          return .failure( .invalidSequence(sequence), finalIndex + 1 )
        }
        return .token( .response(.statusReport(code: code)), finalIndex + 1 )
      case "~":
        return parseTildeTerminatedSequence(parameter: parameter, length: finalIndex + 1 )
      default:
        return .token( .response(.text(sequence)), finalIndex + 1 )
    }
  }

  private func parseTildeTerminatedSequence ( parameter: String, length: Int ) -> ParseResult {
    guard let code = Int(parameter) else { return .failure( .invalidSequence("CSI ~ with non numeric parameter"), length ) }
    switch code {
      case 2  : return .token( .function(.insert), length )
      case 3  : return .token( .function(.delete), length )
      case 5  : return .token( .cursor(.pageUp), length )
      case 6  : return .token( .cursor(.pageDown), length )
      case 15 : return .token( .function(.f(5)), length )
      case 17 : return .token( .function(.f(6)), length )
      case 18 : return .token( .function(.f(7)), length )
      case 19 : return .token( .function(.f(8)), length )
      case 20 : return .token( .function(.f(9)), length )
      case 21 : return .token( .function(.f(10)), length )
      case 23 : return .token( .function(.f(11)), length )
      case 24 : return .token( .function(.f(12)), length )
      default : return .token( .function(.unknown("CSI \(code)~")), length )
    }
  }

  private func parseSS3Sequence () -> ParseResult {
    guard buffer.count > 2 else { return .needMore }
    let code     = buffer[2]
    let sequence = String(decoding: buffer[0 ... 2], as: UTF8.self)
    switch UnicodeScalar(code) {
      case "P": return .token( .function(.f(1)), 3 )
      case "Q": return .token( .function(.f(2)), 3 )
      case "R": return .token( .function(.f(3)), 3 )
      case "S": return .token( .function(.f(4)), 3 )
      case "A": return .token( .cursor(.up), 3 )
      case "B": return .token( .cursor(.down), 3 )
      case "C": return .token( .cursor(.right), 3 )
      case "D": return .token( .cursor(.left), 3 )
      case "H": return .token( .cursor(.home), 3 )
      case "F": return .token( .cursor(.end), 3 )
      default  : return .token( .function(.unknown(sequence)), 3 )
    }
  }

  private func parseOSCSequence () -> ParseResult {
    guard let terminatorIndex = indexOfOSCterminator() else { return .needMore }
    let length   = terminatorIndex + 1
    let content  = buffer[2 ..< terminatorIndex]
    let sequence = String(decoding: buffer[0 ..< length], as: UTF8.self)
    let body     = String(decoding: content, as: UTF8.self)
    let parts    = body.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
    guard let codeString = parts.first, let code = Int(codeString) else {
      return .failure( .invalidSequence(sequence), length )
    }
    let data = parts.count > 1 ? String(parts[1]) : ""
    return .token( .response(.operatingSystemCommand(code: code, data: data)), length )
  }

  private func indexOfOSCterminator () -> Int? {
    var index = 2
    while index < buffer.count {
      let byte = buffer[index]
      if byte == 0x07 {
        return index
      }
      if byte == 0x1B && index + 1 < buffer.count && buffer[index + 1] == 0x5C {
        return index + 1
      }
      index += 1
    }
    return nil
  }

  private func indexOfFinalByte ( startingAt index: Int ) -> Int? {
    var position = index
    while position < buffer.count {
      let byte = buffer[position]
      if byte >= 0x40 && byte <= 0x7E {
        return position
      }
      position += 1
    }
    return nil
  }

  private func parseSGR ( values: [Int] ) -> AnsiFormat.Attributes {
    var attributes = AnsiFormat.Attributes()
    if values.isEmpty {
      return resetAttributes()
    }

    var index = 0
    while index < values.count {
      let value = values[index]
      switch value {
        case 0:
          attributes = resetAttributes()
        case 1:
          attributes.isBold        = true
          attributes.isReset       = false
          attributes.boldSpecified = true
        case 2:
          attributes.isFaint        = true
          attributes.isReset        = false
          attributes.faintSpecified = true
        case 3:
          attributes.isItalic        = true
          attributes.isReset         = false
          attributes.italicSpecified = true
        case 4:
          attributes.isUnderlined        = true
          attributes.isReset             = false
          attributes.underlinedSpecified = true
        case 7:
          attributes.isInverse        = true
          attributes.isReset          = false
          attributes.inverseSpecified = true
        case 22:
          attributes.isBold        = false
          attributes.isFaint       = false
          attributes.isReset       = false
          attributes.boldSpecified = true
          attributes.faintSpecified = true
        case 23:
          attributes.isItalic        = false
          attributes.isReset         = false
          attributes.italicSpecified = true
        case 24:
          attributes.isUnderlined        = false
          attributes.isReset             = false
          attributes.underlinedSpecified = true
        case 27:
          attributes.isInverse        = false
          attributes.isReset          = false
          attributes.inverseSpecified = true
        case 30 ... 37:
          attributes.foreground           = .standard( standardColor(from: value - 30) )
          attributes.foregroundSpecified  = true
          attributes.isReset              = false
        case 40 ... 47:
          attributes.background           = .standard( standardColor(from: value - 40) )
          attributes.backgroundSpecified  = true
          attributes.isReset              = false
        case 90 ... 97:
          attributes.foreground           = .bright( standardColor(from: value - 90) )
          attributes.foregroundSpecified  = true
          attributes.isReset              = false
        case 100 ... 107:
          attributes.background           = .bright( standardColor(from: value - 100) )
          attributes.backgroundSpecified  = true
          attributes.isReset              = false
        case 38:
          if let color = parseExtendedColor(values: values, index: &index) {
            attributes.foreground          = color
            attributes.foregroundSpecified = true
            attributes.isReset             = false
          }
        case 48:
          if let color = parseExtendedColor(values: values, index: &index) {
            attributes.background          = color
            attributes.backgroundSpecified = true
            attributes.isReset             = false
          }
        default:
          break
      }
      index += 1
    }
    return attributes
  }

  private func resetAttributes () -> AnsiFormat.Attributes {
    var attributes = AnsiFormat.Attributes(isReset: true)
    attributes.didReset            = true
    attributes.isBold              = false
    attributes.isFaint             = false
    attributes.isItalic            = false
    attributes.isUnderlined        = false
    attributes.isInverse           = false
    attributes.foreground          = nil
    attributes.background          = nil
    attributes.boldSpecified       = false
    attributes.faintSpecified      = false
    attributes.italicSpecified     = false
    attributes.underlinedSpecified = false
    attributes.inverseSpecified    = false
    attributes.foregroundSpecified = false
    attributes.backgroundSpecified = false
    return attributes
  }

  private func parseExtendedColor ( values: [Int], index: inout Int ) -> AnsiFormat.Attributes.Color? {
    guard index + 1 < values.count else { return nil }
    let mode = values[index + 1]
    switch mode {
      case 2:
        guard index + 4 < values.count else { return nil }
        let red   = UInt8(clamping: values[index + 2])
        let green = UInt8(clamping: values[index + 3])
        let blue  = UInt8(clamping: values[index + 4])
        index += 4
        return .rgb(red: red, green: green, blue: blue)
      case 5:
        guard index + 2 < values.count else { return nil }
        let paletteIndex = UInt8(clamping: values[index + 2])
        index += 2
        return .palette(paletteIndex)
      default:
        return nil
    }
  }

  private func standardColor ( from value: Int ) -> AnsiFormat.Attributes.StandardColor {
    return AnsiFormat.Attributes.StandardColor(rawValue: value) ?? .white
  }

}
