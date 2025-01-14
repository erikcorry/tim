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

  /**
   * Creates a tree that has the numbered lines in it.
   * $root a string, or a Node, including NullNode.
   * zero-based $from, $to.  To is non-inclusive.
   */
  static range root from/int to/int:
    if root is string:
      if from != 0 or to != 1: throw "Invalid range $from-$to"
      return root
    return root.range from to

  static substitute root [block]:
    if root is string: return block.call root
    return root.substitute block

  static append root lines:
    if root is NullNode: return lines
    if lines is NullNode: return root
    return BinaryNode root lines

  static prepend root lines:
    if root is NullNode: return lines
    if lines is NullNode: return root
    return BinaryNode lines root

  static line-count node -> int:
    if node is string: return 1
    return node.line-count

class NullNode extends Node:
  line-count -> int: return 0
  depth -> int: return 0

  stringify -> string: return "(nullnode)"

  static instance := NullNode

  do [block] -> none:
    // Do nothing.

  substitute [block] -> Node:
    return this
  
  dump_ -> string:
    return ""

  dump_ p1/string p2/string p3/string p4/string p5/string -> string:
    return ""

  range from/int to/int -> Node:
    if from != 0 or to != 0: throw "Invalid range"
    return this

  rebalance limit/int -> Node:
    return this

  rebalance_ limit/int --force-single-answer/bool -> List:
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

  do [block] -> none:
    if left is string:
      block.call left
    else:
      left.do block
    if right is string:
      block.call right
    else:
      right.do block

  substitute [block] -> Node:
    new-left := Node.substitute left block
    new-right := Node.substitute right block
    if (identical left new-right) and (identical right new-right): return this
    return BinaryNode new-left new-right
  
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

  /// Rebalance the tree to try to get under a max depth of
  ///   $limit.  Only one rebalancing operation is done, so you
  ///   may need to rerun to get the depth down to the limit.
  ///   If the limit is at least twice the minimum depth of the
  ///   tree it should succeed eventually.
  rebalance limit/int -> Node:
    lcr := rebalance_ (depth - 1) --force-single-answer
    return lcr[1]

  static splat2_ array -> BinaryNode:
    assert: array.size >= 2
    if array.size == 2: return BinaryNode array[0] array[1]
    if array.size == 3: return BinaryNode array[0] (BinaryNode array[1] array[2])
    return BinaryNode
        splat2_ array[.. array.size / 2]
        splat2_ array[array.size / 2 ..]

  /// Return a perfectly rebalanced tree.  Uses a lot of memory if the
  /// tree is very big.
  static splat node/BinaryNode -> BinaryNode:
    max-lines := 1 << node.depth
    if node.line-count * 4 >= max-lines: return node
    array := []
    node.do: array.add it
    return splat2_ array

  rebalance_ limit/int --force-single-answer/bool -> List:
    if left-depth < limit and right-depth < limit: return [NullNode.instance, this, NullNode.instance]

    n1 := null
    n2 := null
    n3 := null
    n4 := null

    if left-depth > right-depth or (left is BinaryNode and right is BinaryNode and left-depth == right-depth and left.line-count < right.line-count):
      lcr := left.rebalance_ (limit - 1) --no-force-single-answer
      n1 = lcr[0]
      n2 = lcr[1]
      n3 = lcr[2]
      n4 = right
    else if right is BinaryNode:
      lcr := right.rebalance_ (limit - 1) --no-force-single-answer
      n1 = left
      n2 = lcr[0]
      n3 = lcr[1]
      n4 = lcr[2]
    else:
      return [NullNode.instance, this, NullNode.instance]
    while n1 is NullNode:
      n1 = n2
      n2 = n3
      n3 = n4
      n4 = NullNode.instance
    while n2 is NullNode and (n3 is not NullNode or n4 is not NullNode):
      n2 = n3
      n3 = n4
      n4 = NullNode.instance
    while n3 is NullNode and n4 is not NullNode:
      n3 = n4
      n4 = NullNode.instance

    n1-depth := (n1 is BinaryNode) ? (n1 as BinaryNode).depth : 1
    n2-depth := (n2 is BinaryNode) ? (n2 as BinaryNode).depth : 1
    n3-depth := (n3 is BinaryNode) ? (n3 as BinaryNode).depth : 1
    n4-depth := (n4 is BinaryNode) ? (n4 as BinaryNode).depth : 1
    if n4 is not NullNode:
      // All 4 are not null.
      if force-single-answer or (n1-depth < limit - 1 and n2-depth < limit - 1 and n3-depth < limit - 1 and n4-depth < limit - 1):
        return [NullNode.instance, BinaryNode (BinaryNode n1 n2) (BinaryNode n3 n4), NullNode.instance]
      else if n3-depth < limit - 1 and n4-depth < limit - 1:
          return [n1, n2, BinaryNode n3 n4]
      else if n1-depth < limit - 1 and n2-depth < limit - 1:
        return [BinaryNode n1 n2, n3, n4]
      else if n2-depth < limit - 1 and n3-depth < limit - 1:
        return [n1, BinaryNode n2 n3, n4]
      if n1-depth + n2-depth < n3-depth + n4-depth:
        return [BinaryNode n1 n2, n3, n4]
      else:
        return [n1, n2, BinaryNode n3 n4]
    if n3 is not NullNode:
      // Three non-null.
      force-left := force-single-answer and (n1-depth <= n3-depth)
      force-right := force-single-answer and not force-left
      if force-left or (n1-depth < limit - 1 and n2-depth < limit - 1 and n3-depth < limit):
        return [NullNode.instance, BinaryNode (BinaryNode n1 n2) n3, NullNode.instance]
      else if force-right or (n1-depth < limit and n2-depth < limit - 1 and n3-depth < limit - 1):
        return [NullNode.instance, BinaryNode n1 (BinaryNode n2 n3), NullNode.instance]
      return [n1, n2, n3]
    if n2 is not NullNode:
      // Two.
      if force-single-answer or (n1-depth < limit - 1 and n2-depth < limit - 1):
        return [NullNode.instance, BinaryNode n1 n2, NullNode.instance]
      return [NullNode.instance, n1, n2]
    return [NullNode.instance, n1, NullNode.instance]

  line n/int -> string:
    if not 0 <= n < line-count: throw "Invalid line"
    if n == 0 and left is string: return left as string
    if n < (Node.line-count left):
      return left.line n
    if n == 1: return right as string
    return right.line (n - (Node.line-count left))

  range from/int to/int:
    left-line-count := Node.line-count left
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
