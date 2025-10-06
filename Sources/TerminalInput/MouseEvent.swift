
import Foundation

extension TerminalInput {
  
  /// Representation of a mouse interaction as reported by terminals that
  /// support the X10, normal tracking, or SGR (1006) mouse modes.  These
  /// reports capture the pointer location, the button that generated the
  /// event, and any modifier keys that were active at the time.
  public struct MouseEvent : Equatable {

    public enum Button : Equatable {
      case left
      case middle
      case right
      case scrollUp
      case scrollDown
      case scrollLeft
      case scrollRight
      case other(Int)
    }

    public enum Action : Equatable {
      case press
      case release
      case drag
      case scroll
    }

    public struct Modifiers : OptionSet, Equatable {
      public let rawValue : Int

      public init ( rawValue: Int ) {
        self.rawValue = rawValue
      }

      public static let shift   = Modifiers(rawValue: 1 << 0)
      public static let option  = Modifiers(rawValue: 1 << 1)
      public static let control = Modifiers(rawValue: 1 << 2)
    }

    public let button    : Button
    public let action    : Action
    public let column    : Int
    public let row       : Int
    public let modifiers : Modifiers

    public init ( button: Button, action: Action, column: Int, row: Int, modifiers: Modifiers ) {
      self.button    = button
      self.action    = action
      self.column    = column
      self.row       = row
      self.modifiers = modifiers
    }

  }
  
  
}
