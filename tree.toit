class Document:
  // Null: Empty document.
  // String: Single-line document.
  // Node: Multi-line document.
  root := NullNode.instance
  previous /Document? := null
  next /Document?  := null

  dump_ -> string:
    if root is string: return root
    return root.dump_

  constructor .root .previous:

  static empty -> Document:
    return empty_

  static empty_ := Document NullNode.instance null

  append lines -> Document:
    if lines is not string and lines is not Node:
      throw "Invalid lines"
    if lines is NullNode: return this
    result /Document := ?
    if root is NullNode:
      result = Document lines this
    else if root is string:
      result = Document (BinaryNode root lines) this
    else:
      result = Document (BinaryNode root lines) this
    next = result
    if result.root is Node: result.root = result.root.rebalance 10
    return result

  prepend lines -> Document:
    if lines is not string and lines is not Node:
      throw "Invalid lines"
    if lines is NullNode: return this
    result /Document := ?
    if root is NullNode:
      result = Document lines this
    else if root is string:
      result = Document (BinaryNode lines root) this
    else:
      result = Document (BinaryNode lines root) this
    next = result
    if result.root is Node: result.root = result.root.rebalance 10
    return result

  static line-count thing -> int:
    if thing is string: return 1
    return thing.line-count

  insert lines at/int -> Document:
    if at == 0: return prepend lines
    line-count := line-count root
    if at == line-count: return append lines
    if not 0 < at < line-count: throw "Invalid at"
    left := range root 0 at
    right := range root at line-count
    result := Document (BinaryNode left (BinaryNode lines right)) this
    next = result
    return result

  do [block] -> none:
    if root is string:
      block.call root
      return
    root.do block

  // How many lines of screen does this $line wrap to?
  static wrap-count_ line/string w/int -> int:
    if line.size <= w: return 1
    return line.size / w

/*
class IterationPoint:
  // The line number.
  line-number /int
  // Whether the iteration point is the string on the left or the right.
  is-left /bool
  // The current node.
  node /Node
  // For left iteration points, this is the parent node.  For right iterations
  // points it may be a higher parent, one that is a parent of the successor.
  parent /IterationPoint?

  constructor .is-left .node .parent:

  line -> string:
    if is-left: return node.left
    return node.right

  next -> IterationPoint:
    if is-left:
      if node.right is string:
        return IterationPoint (line + 1) false node parent
      // Node.right is a node.  We need to move to the left-most child of it.
      grnd-prnt := parent
      prnt := this
      nd := node.right
      while true:
        if n.left is string:
          return IterationPoint (line + 1) false n parent
        prnt = IterationPoint 0 true n prnt
*/

abstract class Node:
  abstract line-count -> int

  abstract do [block] -> none

  abstract dump_ -> string

  abstract dump_ prefix1/string prefix2/string prefix3/string -> string
  
  abstract range from/int to/int -> Node

class NullNode extends Node:
  line-count -> int: return 0
  depth -> int: return 0

  static instance := NullNode
  
  do [block] -> none:
    // Do nothing.

  dump_ -> string:
    return ""

  dump_ prefix1/string prefix2/string prefix3/string -> string:
    return ""

  range from/int to/int -> Node:
    if from != 0 or to != 0: throw "Invalid range"
    return this

  rebalance limit/int -> Node:
    return this

  rebalance_ limit/int -> List:
    return [null, this, null]

class BinaryNode extends Node:
  left := ?
  right := ?
  line-count /int := ?
  depth /int := ?

  constructor .left .right:
    line-count = (left is string ? 1 : left.line-count)
        + (right is string ? 1 : right.line-count)
    depth = 1 + (max (left is string ? 1 : left.depth)
                     (right is string ? 1 : right.depth))

  left-line-count -> int:
    if left is string: return 1
    return left.line-count

  right-line-count -> int:
    if right is string: return 1
    return right.line-count

  do [block] -> none:
    if left is string:
      block.call left
    else:
      left.do block
    if right is string:
      block.call right
    else:
      right.do block

  dump_ -> string:
    return dump_ "" "" ""

  static VERTICAL-BAR ::= "\u{2502}"
  static TOP-CURVE ::= "\u{256D}"
  static BOTTOM-CURVE ::= "\u{2570}"
  static T-SHAPE ::= "\u{2524}"

  dump_ above-prefix/string below-prefix/string parent-connector/string -> string:
    result := ""
    if left is string:
      result += above-prefix + TOP-CURVE + left + "\n"
    else:
      result += left.dump_
          above-prefix + " "
          above-prefix + VERTICAL-BAR
          above-prefix + TOP-CURVE
    result += parent-connector + T-SHAPE + "\n"
    if right is string:
      result += below-prefix + BOTTOM-CURVE + right + "\n"
    else:
      result += right.dump_
          below-prefix + VERTICAL-BAR
          below-prefix + " "
          below-prefix + BOTTOM-CURVE
    return result

    //  |╭a0
    //  ╰┤ ╭a
    //   │╭┤
    //   ╰┤╰b
    //    ╰c

  rebalance limit/int -> Node:
    if depth <= limit: return this
    lcr := rebalance_ (limit / 2)
    l := lcr[0]
    c := lcr[1]
    r := lcr[2]
    if l:
      if r:
        return BinaryNode (BinaryNode l c) r
      return BinaryNode l c
    if r:
      return BinaryNode c r
    return c

  rebalance_ limit/int -> List:
    if left-depth < limit and right-depth < limit:
      return [NullNode.instance, this, NullNode.instance]
    if left-depth > right-depth:
      lcr := left.rebalance_ limit
      l := lcr[0]
      c := lcr[1]
      r := lcr[2]
      if l is not NullNode:
        if r is not NullNode:
          // l, c, r, right
          return [l, c, (BinaryNode r right)]
        return [l, c, right]
      if r is not NullNode:
        return [c, r, right]
      return [NullNode.instance, this, NullNode.instance]
    else:
      lcr := right.rebalance_ limit
      l := lcr[0]
      c := lcr[1]
      r := lcr[2]
      if l is not NullNode:
        if r is not NullNode:
          // left, l, c, r
          return [(BinaryNode left l), c, r]
        return [left, l, c]
      if r is not NullNode:
        return [left, c, r]
      return [NullNode.instance, this, NullNode.instance]

  line n/int -> string:
    if not 0 <= n < line-count: throw "Invalid line"
    if left is Node:
      count := left-line-count
      if n < count: return left.line n
      if n == count and right is string: return right
      return right.line (n - count)
    if n == 0: return left
    return right.line (n - 1)

  range from/int to/int:
    if from == 0 and to == line-count: return this
    if to <= left-line-count: return left-range from to
    if from >= left-line-count:
      return right-range (from - left-line-count) (to - left-line-count)
    return BinaryNode
        (left-range from left-line-count)
        (right-range 0 (to - left-line-count))

  left-depth -> int:
    if left is string: return 1
    return left.depth

  right-depth -> int:
    if right is string: return 1
    return right.depth

  left-range from/int to/int:
    if left is string:
      if from == 0 and to == 1: return left
      throw "Invalid range"
    return left.range from to

  right-range from/int to/int:
    if right is string:
      if from == 0 and to == 1: return right
      throw "Invalid range"
    return right.range from to

join_ node/Node divider/string -> string:
  array := []
  node.do: array.add it
  return array.join divider

/**
 * Creates a collection that has the numbered lines in it.
 * $root a string, or a Node, including NullNode.
 * zero-based $from, $to.  To is non-inclusive.
 */
range root from/int to/int:
  if root is string:
    if from != 0 or to != 1: throw "Invalid range $from-$to"
    return root
  return root.range from to
