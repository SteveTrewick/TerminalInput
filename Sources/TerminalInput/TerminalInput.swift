import Foundation


public class TerminalInput {
  
  //TODO: we will need a stateful parser for xterm input over stdin
  
  public var dispatch : ( (Result<Token, Error>) -> Void )?
  
  public enum Error : Swift.Error {
    //TODO: error definitions go here
  }
  
  public enum Token {
    //TODO: token defintions go here
  }
  
  public func enqueue ( _ bytes: Data ) {
    //TODO: parser invocations go here, when we have a token to emit, we call dispatch
  }

}
