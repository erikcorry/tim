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
    if result.root is Node: result.root = result.root.rebalance 20
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
    if result.root is Node: result.root = result.root.rebalance 20
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

  abstract dump_ p1/string p2/string p3/string p4/string p5/string -> string
  
  abstract range from/int to/int -> Node

class NullNode extends Node:
  line-count -> int: return 0
  depth -> int: return 0

  stringify -> string: return "(nullnode)"

  static instance := NullNode
  
  do [block] -> none:
    // Do nothing.

  dump_ -> string:
    return ""

  dump_ p1/string p2/string p3/string p4/string p5/string -> string:
    return ""

  range from/int to/int -> Node:
    if from != 0 or to != 0: throw "Invalid range"
    return this

  rebalance limit/int -> Node:
    return this

  rebalance_ limit/int -> List:
    return [NullNode.instance, this, NullNode.instance]

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
    return dump_ "" "" "" "" ""

  static VERTICAL-BAR ::= "\u{2502}"
  static TOP-CURVE ::= "\u{256D}"
  static BOTTOM-CURVE ::= "\u{2570}"
  static T-SHAPE ::= "\u{2524}"

  dump_ top-prefix above-prefix/string parent-connector/string below-prefix/string bottom-prefix/string -> string:
    result := ""
    // 0 = top does connector
    // 1 = bottom does connector
    // 2 = we do connector.
    connector-type := ?
    if left is not string and left is not NullNode:
      connector-type = 0
    else if right is not string and right is not NullNode:
      connector-type = 1
    else:
      connector-type = 2
    if left is string or left is NullNode:
      result += top-prefix + TOP-CURVE + left.stringify + "\n"
    else:
      result += left.dump_
          top-prefix + " "
          above-prefix + " "
          above-prefix + TOP-CURVE
          above-prefix + VERTICAL-BAR
          connector-type == 0
              ? parent-connector + T-SHAPE
              : above-prefix + VERTICAL-BAR
    if connector-type == 2: result += parent-connector + T-SHAPE + "\n"
    if right is string or right is NullNode:
      result += bottom-prefix + BOTTOM-CURVE + right.stringify + "\n"
    else:
      result += right.dump_
          connector-type == 1
              ? parent-connector + T-SHAPE
              : below-prefix + VERTICAL-BAR
          below-prefix + VERTICAL-BAR
          below-prefix + BOTTOM-CURVE
          below-prefix + " "
          bottom-prefix + " "
    return result

    //  |╭a0
    //  ╰┤ ╭a
    //   │╭┤
    //   ╰┤╰b
    //    ╰c

  rebalance limit/int -> Node:
    self := this
    while self.depth > limit:
      print "Rebalancing, depth is $self.depth > $limit"
      lcr := self.rebalance_ (limit / 3)
      l := lcr[0]
      c := lcr[1]
      r := lcr[2]
      if l is not NullNode:
        if r is not NullNode:
          print "binarynode"
          print "binarynode"
          self = BinaryNode (BinaryNode l c) r
        else:
          print "binarynode"
          self = BinaryNode l c
      else if r is not NullNode:
        print "binarynode"
        self = BinaryNode c r
      else:
        self = c
      print "after: depth is $self.depth"
    return self

  splat2_ array -> BinaryNode:
    assert: array.size >= 2
    if array.size == 2: return BinaryNode array[0] array[1]
    if array.size == 3: return BinaryNode array[0] (BinaryNode array[1] array[2])
    return BinaryNode
        splat2_ array[.. array.size / 2]
        splat2_ array[array.size / 2 ..]

  splat_ node/BinaryNode -> BinaryNode:
    max-lines := 1 << node.depth
    if node.line-count * 4 < max-lines:
      array := []
      node.do: array.add it
      return splat2_ array
    return node

  rebalance_ limit/int -> List:
    if left-depth < limit and right-depth < limit:
      if left-depth > right-depth:
        l := splat_ (left as BinaryNode)
        return [left, right, NullNode.instance]
      else if right-depth > limit / 2:
        r := splat_ (right as BinaryNode)
        return [NullNode.instance, left, r]
    if left-depth > right-depth:
      lcr := left.rebalance_ limit
      l := lcr[0]
      c := lcr[1]
      r := lcr[2]
      if l is not NullNode:
        if r is not NullNode:
          left-depth := (l is string) ? 1 : l.depth
          right-depth := (right is string) ? 1 : right.depth
          if left-depth < right-depth:
            print "binarynode"
            return [(BinaryNode l c), r, right]
          else:
            print "binarynode"
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
          left-depth := (left is string) ? 1 : left.depth
          right-depth := (r is string) ? 1 : r.depth
          if left-depth < right-depth:
            print "binarynode"
            return [(BinaryNode left l), c, r]
          else:
            print "binarynode"
            return [left, l, (BinaryNode c r)]
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
