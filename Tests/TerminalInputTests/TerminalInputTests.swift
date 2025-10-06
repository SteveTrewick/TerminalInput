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
    let expectedAttributes = TerminalInput.AnsiFormat.Attributes(formats: [.isBold],
                                                                 foreground: .standard(.red))
    let expected = TerminalInput.Token.ansi( TerminalInput.AnsiFormat(sequence: "\u{001B}[1;31m",
                                                                      attributes: expectedAttributes) )
    XCTAssertEqual(tokens, [ expected ])
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
    XCTAssertTrue(formatToken.attributes.formats.contains(.isBold))
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
