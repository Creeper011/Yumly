##
# This module defines the Recursive Descent Parser for the Yumly configuration language.
# It pulls tokens on-demand from a closure iterator
##

import ../../types/[document, nodes, token]
import ./[puller, state]

proc parseNodes*(puller: TokenPuller,
    documentKind: DocumentKind = dkConfig): NodePuller =
  ## Parses a list of nodes from the given puller.
  ##
  ## It creates a parser and returns a node closure.
  var parser = newParser(puller, documentKind)

  proc nextNode(): YumNode {.closure.} =
    result = parser.pullNode()
    if result != nil and result.sourceFile == nil:
      result.sourceFile = result.token.source.source

  nextNode
