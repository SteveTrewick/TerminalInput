import Foundation


/// `TerminalInput` turns the stream of bytes that arrives from a terminal into a
/// sequence of easy to understand Swift values.  The goal is to shield the rest
/// of the application from the confusing details of escape codes, which are the
/// little signals a terminal uses to describe special keys, colours, or status
/// reports.  Someone reading the tokens produced by this class never has to
/// understand the shape of an ANSI escape sequence to react to user input.
public final class TerminalInput {

  /// Callback that receives every parsed token or error.  You may think of it
  /// as the delivery belt that carries the decoded results to the rest of the
  /// program.
  public var dispatch : ( (Result<Token, Error>) -> Void )?

  /// Errors that can occur while decoding the incoming bytes.  They point out
  /// either malformed text (bad UTF-8) or escape sequences that do not follow
  /// the rules documented for terminals.
  public enum Error : Swift.Error, Equatable {
    case invalidUTF8(Data)
    case invalidSequence(String)
  }

  /// The kinds of tokens that may be produced while reading the input stream.
  /// Each case wraps a more specific type that carries the meaning of the
  /// terminal event.
  public enum Token : Equatable {
    case text(String)
    case control(ControlKey)
    case cursor(CursorKey)
    case function(FunctionKey)
    case meta(MetaKey)
    case response(TerminalResponse)
    case ansi(AnsiFormat)
    case mouse(MouseEvent)
  }



  /// Non-printable control characters, such as carriage return and tab.  These
  /// values come directly from the ASCII control area and represent the oldest
  /// parts of terminal communication.
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

    public init? ( byte: UInt8 ) {
      switch byte {
        case 0x00 : self = .NULL
        case 0x01 : self = .SOH
        case 0x02 : self = .STX
        case 0x03 : self = .ETX
        case 0x04 : self = .EOT
        case 0x05 : self = .ENQ
        case 0x06 : self = .ACK
        case 0x07 : self = .BEL
        case 0x08 : self = .BACKSPACE
        case 0x09 : self = .TAB
        case 0x0A : self = .LF
        case 0x0B : self = .VT
        case 0x0C : self = .FF
        case 0x0D : self = .RETURN
        case 0x0E : self = .SO
        case 0x0F : self = .SI
        case 0x10 : self = .DLE
        case 0x11 : self = .DC1
        case 0x12 : self = .DC2
        case 0x13 : self = .DC3
        case 0x14 : self = .DC4
        case 0x15 : self = .NAK
        case 0x16 : self = .SYN
        case 0x17 : self = .ETB
        case 0x18 : self = .CAN
        case 0x19 : self = .EM
        case 0x1A : self = .SUB
        case 0x1C : self = .FS
        case 0x1D : self = .GS
        case 0x1E : self = .RS
        case 0x1F : self = .US
        case 0x7F : self = .DEL
        default   : return nil
      }
    }
  }

  /// Movement keys that are usually produced by the arrow cluster or the
  /// navigation block on a keyboard.
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

  /// Higher level keys that either correspond to the labelled function keys or
  /// are utility keys such as insert/delete.
  public enum FunctionKey : Equatable {
    case f(Int)
    case insert
    case delete
    case unknown(String)
  }

  /// Escape-derived combinations, such as pressing the option/alt key in
  /// conjunction with a printable character, or the escape key by itself.
  public enum MetaKey : Equatable {
    case alt(Character)
    case escape
  }

  /// Messages sent from the terminal to report internal state.  These are most
  /// often responses to earlier queries such as “where is the cursor right now?”
  /// or “what kind of terminal are you?”.
  public enum TerminalResponse : Equatable {
    case cursorPosition(row: Int, column: Int)
    case deviceAttributes(values: [Int], isPrivate: Bool)
    case statusReport(code: Int)
    case operatingSystemCommand(code: Int, data: String)
    case text(String)
  }

  /// Wrapper for a Select Graphic Rendition (SGR) escape sequence.  The
  /// `sequence` string contains the exact text that was read from the terminal
  /// while `attributes` breaks it down into a friendlier structure.
  /// Reference: Xterm Control Sequences, “Graphics Rendition” section.
  /// https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
  public struct AnsiFormat : Equatable {

    /// The raw escape sequence, useful when the exact bytes need to be replayed
    /// to another terminal or logged for inspection.
    public let sequence   : String
    /// Parsed representation of the stylistic changes requested by the
    /// sequence.
    public let attributes : Attributes

  }

  /// Creates a parser that is ready to receive input.
  public init () { }

  /// Adds a new batch of bytes to the parser.  The terminal can deliver data in
  /// unpredictable chunks, so this method stores the bytes and then repeatedly
  /// tries to decode complete tokens.
  public func enqueue ( _ bytes: Data ) {
    buffer.append(bytes)
    processBuffer()
  }

  /// Temporary storage that accumulates bytes until enough information is
  /// present to produce a token.
  private var buffer : Data = Data()

  /// Represents the outcome of attempting to read a single token from the
  /// buffer.  A token may be produced, more bytes may be required, or an error
  /// could be reported together with the number of bytes that were examined.
  private enum ParseResult {
    case token(Token, Int)
    case needMore
    case failure(Error, Int)
  }

  /// Continually pulls tokens from the buffer until there are not enough bytes
  /// to continue.  Each successful token or error is sent through the dispatch
  /// callback.
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

  /// Decides how to interpret the next byte in the buffer.  Printable text is
  /// gathered into `Token.text`, control characters are mapped to the
  /// `ControlKey` enumeration, and escape sequences are delegated to specialised
  /// helpers.
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

  /// Converts a raw ASCII control character into the matching `ControlKey`
  /// value.  Only bytes in the standard control ranges are recognised; all
  /// others fall back to printable handling.
  private func parseControl ( _ byte: UInt8 ) -> ControlKey? {
    return ControlKey(byte: byte)
  }

  /// Collects consecutive printable characters and turns them into a Swift
  /// string token.  Any encounter with a control byte ends the text run so that
  /// a different token can be produced for the special action.
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

  /// Interprets the escape character (`ESC`) that introduces higher level
  /// sequences.  Depending on the second byte the method forwards to the
  /// correct helper for Control Sequence Introducer (CSI), Single Shift Select
  /// (SS3), Operating System Command (OSC), or meta key sequences.
  /// Reference: Xterm Control Sequences, “Escape Sequences” overview.
  /// https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
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

  /// Handles ALT-modified key presses.  The terminal sends `ESC` followed by
  /// the actual character, so this method waits for the second byte and then
  /// emits a `.meta(.alt)` token.
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

  /// Decodes Control Sequence Introducer (CSI) sequences.  These start with the
  /// characters `ESC [` and contain a final byte that identifies the action.
  /// Reference: ECMA-48 / ISO 6429 Section 5.4.
  /// https://www.ecma-international.org/publications-and-standards/standards/ecma-48/
  private func parseCSISequence () -> ParseResult {
    guard let finalIndex = indexOfFinalByte(startingAt: 2) else { return .needMore }
    let finalByte     = buffer[finalIndex]
    let parameterData = buffer[2 ..< finalIndex]
    let sequenceData  = buffer[0 ... finalIndex]
    let sequence      = String(decoding: sequenceData, as: UTF8.self)
    let parameter     = String(decoding: parameterData, as: UTF8.self)

    if (finalByte == 0x4D || finalByte == 0x6D) && parameter.hasPrefix("<") {
      return parseSGRMouseSequence(parameter: parameter, finalIndex: finalIndex, finalByte: finalByte, sequence: sequence)
    }

    if finalByte == 0x4D && parameter.isEmpty {
      return parseLegacyMouseSequence(finalIndex: finalIndex)
    }

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
        let components = parameter.split(separator: ";", omittingEmptySubsequences: false)
        let values     = components.compactMap { substring -> Int? in
          if substring.isEmpty { return 0 }
          return Int(substring)
        }
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

  /// Decodes SGR (1006) mouse tracking sequences with the form `CSI <Cb;Cx;CyM`
  /// or `CSI <Cb;Cx;Cym`.  The three parameters represent the button/mask,
  /// column, and row respectively.
  private func parseSGRMouseSequence ( parameter: String, finalIndex: Int, finalByte: UInt8, sequence: String ) -> ParseResult {
    let length      = finalIndex + 1
    let parameter   = parameter.dropFirst()
    let components  = parameter.split(separator: ";", omittingEmptySubsequences: false)
    guard components.count == 3,
          let code = Int(components[0]),
          let column = Int(components[1]),
          let row = Int(components[2]),
          let event = decodeMouseEvent(code: code, column: column, row: row, finalByte: finalByte) else {
      return .failure( .invalidSequence(sequence), length )
    }
    return .token( .mouse(event), length )
  }

  /// Parses the legacy X10 / normal tracking mouse packets `ESC [ M cb cx cy`.
  /// The three bytes following the final `M` encode the button mask and
  /// coordinates offset by 32.
  private func parseLegacyMouseSequence ( finalIndex: Int ) -> ParseResult {
    let length = finalIndex + 4
    guard buffer.count >= length else { return .needMore }

    let codeByte   = buffer[finalIndex + 1]
    let columnByte = buffer[finalIndex + 2]
    let rowByte    = buffer[finalIndex + 3]
    let code       = Int(codeByte) - 32
    let column     = Int(columnByte) - 32
    let row        = Int(rowByte) - 32

    let sequenceData = buffer[0 ..< length]
    let sequence     = String(decoding: sequenceData, as: UTF8.self)

    guard code >= 0,
          column >= 0,
          row >= 0,
          let event = decodeMouseEvent(code: code, column: column, row: row, finalByte: 0x4D) else {
      return .failure( .invalidSequence(sequence), length )
    }

    return .token( .mouse(event), length )
  }

  private func decodeMouseEvent ( code: Int, column: Int, row: Int, finalByte: UInt8 ) -> MouseEvent? {
    guard column >= 0, row >= 0 else { return nil }

    let modifiers = mouseModifiers(from: code)
    let isScroll  = (code & 0x40) != 0
    let isDrag    = (code & 0x20) != 0
    let buttonId  = code & 0x03

    if isScroll {
      let button : MouseEvent.Button
      switch buttonId {
        case 0 : button = .scrollUp
        case 1 : button = .scrollDown
        case 2 : button = .scrollLeft
        case 3 : button = .scrollRight
        default: return nil
      }
      return MouseEvent( button: button,
                         action: .scroll,
                         column: column,
                         row: row,
                         modifiers: modifiers )
    }

    let button : MouseEvent.Button
    switch buttonId {
      case 0 : button = .left
      case 1 : button = .middle
      case 2 : button = .right
      case 3 : button = .other(buttonId)
      default: return nil
    }

    let action : MouseEvent.Action
    if finalByte == 0x6D || buttonId == 3 {
      action = .release
    } else if isDrag {
      action = .drag
    } else {
      action = .press
    }

    return MouseEvent( button: button,
                       action: action,
                       column: column,
                       row: row,
                       modifiers: modifiers )
  }

  private func mouseModifiers ( from code: Int ) -> MouseEvent.Modifiers {
    var modifiers = MouseEvent.Modifiers()
    if (code & 0x04) != 0 { modifiers.insert(.shift) }
    if (code & 0x08) != 0 { modifiers.insert(.option) }
    if (code & 0x10) != 0 { modifiers.insert(.control) }
    return modifiers
  }

  /// Parses CSI sequences that end with the tilde character.  These are commonly
  /// used for keys that do not have a dedicated letter code, such as Insert or
  /// Page Up.
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

  /// Processes SS3 sequences, often produced when the terminal is in “application
  /// keypad” mode.  They have the form `ESC O <code>` and cover early function
  /// keys as well as arrow keys in certain modes.
  /// Reference: Xterm Control Sequences, “SS3 – Single Shift 3”.
  /// https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
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

  /// Parses Operating System Command (OSC) sequences.  These begin with `ESC ]`
  /// and are terminated either by the BEL character or by `ESC \`.  Terminals
  /// use OSC codes for tasks such as setting the window title or clipboard.
  /// Reference: Xterm Control Sequences, “Operating System Commands”.
  /// https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
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

  /// Scans the buffer to find the end of an OSC sequence.  The OSC body is
  /// terminated either by BEL or by the two-character string `ESC \`.
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

  /// Determines the position of the final byte in a CSI sequence.  The range
  /// 0x40...0x7E is reserved for these final selectors by ECMA-48, so reaching a
  /// byte in that range means the sequence is complete.
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

  /// Interprets Select Graphic Rendition (SGR) values, which are the numeric
  /// parameters found inside a `CSI ... m` sequence.  Each value toggles a
  /// specific visual property such as bold, underline, or colour.
  private func parseSGR ( values: [Int] ) -> AnsiFormat.Attributes {
    var attributes = AnsiFormat.Attributes()
    if values.isEmpty {
      return resetAttributes()
    }

    var index    = 0
    var sawReset = false
    while index < values.count {
      let value = values[index]
      switch value {
        case 0:
          attributes = resetAttributes()
          sawReset   = true
        case 1:
          attributes.setAttribute(.bold, enabled: true)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 2:
          attributes.setAttribute(.faint, enabled: true)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 3:
          attributes.setAttribute(.italic, enabled: true)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 4:
          attributes.setAttribute(.underlined, enabled: true)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 7:
          attributes.setAttribute(.inverse, enabled: true)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 22:
          attributes.setAttribute(.bold, enabled: false)
          attributes.setAttribute(.faint, enabled: false)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 23:
          attributes.setAttribute(.italic, enabled: false)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 24:
          attributes.setAttribute(.underlined, enabled: false)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 27:
          attributes.setAttribute(.inverse, enabled: false)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 30 ... 37:
          attributes.foreground = .standard( standardColor(from: value - 30) )
          attributes.setAttribute(.foreground, enabled: true)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 39:
          attributes.foreground = nil
          attributes.setAttribute(.foreground, enabled: false)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 40 ... 47:
          attributes.background = .standard( standardColor(from: value - 40) )
          attributes.setAttribute(.background, enabled: true)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 49:
          attributes.background = nil
          attributes.setAttribute(.background, enabled: false)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 90 ... 97:
          attributes.foreground = .bright( standardColor(from: value - 90) )
          attributes.setAttribute(.foreground, enabled: true)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 100 ... 107:
          attributes.background = .bright( standardColor(from: value - 100) )
          attributes.setAttribute(.background, enabled: true)
          if !sawReset { attributes.clearAttribute(.reset) }
        case 38:
          if let color = parseExtendedColor(values: values, index: &index) {
            attributes.foreground = color
            attributes.setAttribute(.foreground, enabled: true)
            if !sawReset { attributes.clearAttribute(.reset) }
          }
        case 48:
          if let color = parseExtendedColor(values: values, index: &index) {
            attributes.background = color
            attributes.setAttribute(.background, enabled: true)
            if !sawReset { attributes.clearAttribute(.reset) }
          }
        default:
          break
      }
      index += 1
    }
    return attributes
  }

  /// Constructs an attribute set that represents the “clear all styles” state.
  /// ANSI defines SGR 0 as a full reset, so this helper applies the same idea to
  /// the high level structure.
  private func resetAttributes () -> AnsiFormat.Attributes {
    var attributes = AnsiFormat.Attributes()
    attributes.foreground   = nil
    attributes.background   = nil
    attributes.clearMarks()
    attributes.setAttribute(.reset, enabled: true)
    return attributes
  }

  /// Handles the extended colour modes that follow SGR 38 (foreground) and SGR
  /// 48 (background).  These cover 256-colour palette indexes and 24-bit RGB
  /// values.
  /// Reference: Xterm Control Sequences, “SGR 38;2 and 48;2”.
  /// https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
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

  /// Maps colour codes 0...7 onto the classic ANSI colour palette.  The mapping
  /// is identical for normal and bright variants, the caller decides which is in
  /// effect.
  private func standardColor ( from value: Int ) -> AnsiFormat.Attributes.StandardColor {
    return AnsiFormat.Attributes.StandardColor(rawValue: value) ?? .white
  }

}
