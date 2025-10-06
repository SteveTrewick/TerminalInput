# TerminalInput

We will take input from stdin in the form of multiple callss to TerminalInput.enqueue and
generate output tokens. We will distinguish  control, cursor, meta key sequences, 
terminal responses and any other possible inputs the macos xterm terminal can generate 
as well as, of couse, just plain text.

For ANSI sequences denoting format, bold, underline, color, etc we ahould emit a token that 
captures both the attributes and the original ANSI sequence so we can either print it or use 
it in a non terminal context.
 

## Deliverable 
A Swift 5 package that reads a stream of data from macos xterm and parses it into useful tokens 

# You Must
## Use Swift 5 compatible syntax at all times, do not use async/await
## Read the rules in STYLERULES.md
## Apply the coding style rules in STYLERULES.md

# Compatibility
## Target platform is macOS version 11
## Linux compatibility is desirable, at a mimimum, code should compile for testing on linux

