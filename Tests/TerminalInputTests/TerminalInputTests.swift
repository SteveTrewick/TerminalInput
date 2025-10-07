import XCTest
@testable import TerminalInput


final class TerminalInputTests: XCTestCase {

  func testPlainTextEmission () {
    let tokens = captureTokens(from: Data("hello".utf8))
    XCTAssertEqual(tokens, [ .text("hello") ])
  }

  func testControlCharacterEmission () {
    let tokens = captureTokens(from: Data([0x07]))
    XCTAssertEqual(tokens, [ .control(.BEL) ])
  }

  func testEscapeKeyEmission () {
    let tokens = captureTokens(from: Data([0x1B]))
    XCTAssertEqual(tokens, [ .escape ])
  }

  func testEscapeBeforeControlCharacter () {
    let data   = Data([0x1B, 0x01])
    let tokens = captureTokens(from: data)
    XCTAssertEqual(tokens, [ .escape, .control(.SOH) ])
  }

  func testArrowKeyParsing () {
    let data    = Data([0x1B, 0x5B, 0x41])
    let tokens  = captureTokens(from: data)
    XCTAssertEqual(tokens, [ .cursor(.up) ])
  }

  func testFunctionKeyParsing () {
    let data    = Data([0x1B, 0x5B, 0x31, 0x35, 0x7E])
    let tokens  = captureTokens(from: data)
    XCTAssertEqual(tokens, [ .function(.f(5)) ])
  }

  func testSS3FunctionKeyParsing () {
    let data    = Data([0x1B, 0x4F, 0x50])
    let tokens  = captureTokens(from: data)
    XCTAssertEqual(tokens, [ .function(.f(1)) ])
  }

  func testSGRParsing () {
    let data    = Data("\u{001B}[1;31m".utf8)
    let tokens  = captureTokens(from: data)
    var expectedAttributes = TerminalInput.AnsiFormat.Attributes()
    expectedAttributes.setAttribute(.bold, enabled: true)
    expectedAttributes.foreground = .standard(.red)
    expectedAttributes.setAttribute(.foreground, enabled: true)
    let expected = TerminalInput.Token.ansi( TerminalInput.AnsiFormat(sequence: "\u{001B}[1;31m",
                                                                      attributes: expectedAttributes) )
    XCTAssertEqual(tokens, [ expected ])
  }

  func testSGRParsingTreatsEmptyParameterAsReset () {
    let data    = Data("\u{001B}[;31m".utf8)
    let tokens  = captureTokens(from: data)
    guard case let .ansi(formatToken) = tokens.first else {
      XCTFail("Expected ANSI token")
      return
    }

    let parser   = TerminalInput.AnsiFormat.AttributeParser()
    let parsed   = parser.parse(attributes: formatToken.attributes)
    let expected : [TerminalInput.AnsiFormat.Attribute] = [
      .reset,
      .foreground(.standard(.red))
    ]

    XCTAssertEqual(parsed, expected)
  }

  func testSGRParsingHandlesMultipleEmptyParameters () {
    let data    = Data("\u{001B}[1;;32m".utf8)
    let tokens  = captureTokens(from: data)
    guard case let .ansi(formatToken) = tokens.first else {
      XCTFail("Expected ANSI token")
      return
    }

    let parser   = TerminalInput.AnsiFormat.AttributeParser()
    let parsed   = parser.parse(attributes: formatToken.attributes)
    let expected : [TerminalInput.AnsiFormat.Attribute] = [
      .reset,
      .foreground(.standard(.green))
    ]

    XCTAssertEqual(parsed, expected)
  }

  func testCursorPositionResponseParsing () {
    let data    = Data("\u{001B}[12;45R".utf8)
    let tokens  = captureTokens(from: data)
    XCTAssertEqual(tokens, [ .response(.cursorPosition(row: 12, column: 45)) ])
  }

  func testOperatingSystemCommandParsing () {
    let data    = Data("\u{001B}]0;Title\u{0007}".utf8)
    let tokens  = captureTokens(from: data)
    XCTAssertEqual(tokens, [ .response(.operatingSystemCommand(code: 0, data: "Title")) ])
  }

  func testMetaAltSequenceParsing () {
    let data    = Data([0x1B, 0x78])
    let tokens  = captureTokens(from: data)
    XCTAssertEqual(tokens, [ .meta(.alt("x")) ])
  }

  func testMouseSGRPressParsing () {
    let data    = Data("\u{001B}[<0;10;5M".utf8)
    let tokens  = captureTokens(from: data)
    let event   = TerminalInput.MouseEvent( button: .left,
                                            action: .press,
                                            column: 10,
                                            row: 5,
                                            modifiers: [] )
    XCTAssertEqual(tokens, [ .mouse(event) ])
  }

  func testMouseSGRReleaseParsing () {
    let data    = Data("\u{001B}[<0;10;5m".utf8)
    let tokens  = captureTokens(from: data)
    let event   = TerminalInput.MouseEvent( button: .left,
                                            action: .release,
                                            column: 10,
                                            row: 5,
                                            modifiers: [] )
    XCTAssertEqual(tokens, [ .mouse(event) ])
  }

  func testMouseSGRDragWithModifiersParsing () {
    let data    = Data("\u{001B}[<44;12;8M".utf8)
    let tokens  = captureTokens(from: data)
    let modifiers : TerminalInput.MouseEvent.Modifiers = [ .shift, .option ]
    let event      = TerminalInput.MouseEvent( button: .left,
                                               action: .drag,
                                               column: 12,
                                               row: 8,
                                               modifiers: modifiers )
    XCTAssertEqual(tokens, [ .mouse(event) ])
  }

  func testMouseSGRScrollParsing () {
    let data    = Data("\u{001B}[<64;22;18M".utf8)
    let tokens  = captureTokens(from: data)
    let event   = TerminalInput.MouseEvent( button: .scrollUp,
                                            action: .scroll,
                                            column: 22,
                                            row: 18,
                                            modifiers: [] )
    XCTAssertEqual(tokens, [ .mouse(event) ])
  }

  func testMouseLegacyX10PacketParsing () {
    let data    = Data([0x1B, 0x5B, 0x4D, 0x20, 0x2A, 0x25])
    let tokens  = captureTokens(from: data)
    let event   = TerminalInput.MouseEvent( button: .left,
                                            action: .press,
                                            column: 10,
                                            row: 5,
                                            modifiers: [] )
    XCTAssertEqual(tokens, [ .mouse(event) ])
  }

  func testBufferedCSISequenceAcrossChunks () {
    let input    = TerminalInput()
    var tokens   : [TerminalInput.Token] = []
    var failures : [TerminalInput.Error] = []

    input.dispatch = { result in
      switch result {
        case .success(let token) : tokens.append(token)
        case .failure(let error) : failures.append(error)
      }
    }

    input.enqueue( Data([0x1B, 0x5B, 0x31, 0x3B]) )
    XCTAssertTrue(tokens.isEmpty)

    input.enqueue( Data([0x33, 0x31, 0x6D]) )
    XCTAssertEqual(tokens.count, 1)
    XCTAssertTrue(failures.isEmpty)

    guard case let .ansi(formatToken) = tokens.first else {
      XCTFail("Expected ANSI token")
      return
    }

    XCTAssertEqual(formatToken.sequence, "\u{001B}[1;31m")
    XCTAssertTrue(formatToken.attributes.isAttributeEnabled(.bold) ?? false)
  }

  func testAttributeParserEnumeratesAttributes () {
    let data    = Data("\u{001B}[1;38;5;12m".utf8)
    let tokens  = captureTokens(from: data)
    guard case let .ansi(formatToken) = tokens.first else {
      XCTFail("Expected ANSI token")
      return
    }

    let parser        = TerminalInput.AnsiFormat.AttributeParser()
    let parsed        = parser.parse(attributes: formatToken.attributes)
    let expectedColor = TerminalInput.AnsiFormat.Attributes.Color.palette(12)
    XCTAssertEqual(parsed, [ .bold(true), .foreground(expectedColor) ])
  }

  func testAttributeParserCapturesDisabledAttributes () {
    let data    = Data("\u{001B}[22m".utf8)
    let tokens  = captureTokens(from: data)
    guard case let .ansi(formatToken) = tokens.first else {
      XCTFail("Expected ANSI token")
      return
    }

    let parser = TerminalInput.AnsiFormat.AttributeParser()
    let parsed = parser.parse(attributes: formatToken.attributes)
    XCTAssertEqual(parsed, [ .bold(false), .faint(false) ])
  }

  func testSGRForegroundDefaultParsing () {
    let data    = Data("\u{001B}[39m".utf8)
    let tokens  = captureTokens(from: data)
    guard case let .ansi(formatToken) = tokens.first else {
      XCTFail("Expected ANSI token")
      return
    }

    XCTAssertNil(formatToken.attributes.foreground)
    XCTAssertEqual(formatToken.attributes.isAttributeEnabled(.foreground), false)

    let parser = TerminalInput.AnsiFormat.AttributeParser()
    let parsed = parser.parse(attributes: formatToken.attributes)
    XCTAssertEqual(parsed, [ .foregroundDefault ])
  }

  func testSGRBackgroundDefaultParsing () {
    let data    = Data("\u{001B}[49m".utf8)
    let tokens  = captureTokens(from: data)
    guard case let .ansi(formatToken) = tokens.first else {
      XCTFail("Expected ANSI token")
      return
    }

    XCTAssertNil(formatToken.attributes.background)
    XCTAssertEqual(formatToken.attributes.isAttributeEnabled(.background), false)

    let parser = TerminalInput.AnsiFormat.AttributeParser()
    let parsed = parser.parse(attributes: formatToken.attributes)
    XCTAssertEqual(parsed, [ .backgroundDefault ])
  }

  private func captureTokens ( from data: Data ) -> [TerminalInput.Token] {
    let input    = TerminalInput()
    var tokens   : [TerminalInput.Token] = []
    var failures : [TerminalInput.Error] = []

    input.dispatch = { result in
      switch result {
        case .success(let token) : tokens.append(token)
        case .failure(let error) : failures.append(error)
      }
    }

    input.enqueue(data)
    XCTAssertTrue(failures.isEmpty)
    return tokens
  }

}
