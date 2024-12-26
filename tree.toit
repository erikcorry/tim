class Document:
  // Null: Empty document.
  // String: Single-line document.
  // Node: Multi-line document.
  root := null
  previous /Document? := null
  next /Document?  := null

  dump_ -> string:
    if root == null: return "(null)"
    if root is string: return root
    return root.dump_

  constructor .root .previous:

  static empty -> Document:
    return empty_

  static empty_ := Document null null

  append lines -> Document:
    if lines != null and lines is not string and lines is not Node:
      throw "Invalid lines"
    if root == null: return Document lines this
    if lines == null: return this
    result := Document (Node root lines) this
    next = result
    return result

  prepend lines -> Document:
    if lines != null and lines is not string and lines is not Node:
      throw "Invalid lines"
    if root == null: return Document lines this
    if lines == null: return this
    result := Document (Node lines root) this
    next = result
    return result

  insert lines at/int -> Document:
    if at == 0: return prepend lines
    line-count := line-count root
    if at == line-count: return append lines
    if not 0 < at < line-count: throw "Invalid at"
    left := range root 0 at
    right := range root at line-count
    result := Document (Node left (Node lines right)) this
    next = result
    return result

  // Pivot tree to put nth line near the top.  This is a mutating method, but
  // it doesn't change the document, just the data structure storing it.
  rebase at/int -> none:
    total-lines := line-count root
    if not 0 <= at < total-lines: throw "Invalid at"
    left := (at == 0) ? null : (range root 0 at)
    right := (at == total-lines - 1) ? null : (range root (at + 1) total-lines)
    new-root-line/string := line root at
    if left == null: 
      root = Node new-root-line right
    else if right == null:
      root = Node left new-root-line
    else:
      root = Node left (Node new-root-line right)

  do [block] -> none:
    if root == null: return
    if root is string:
      block.call root
      return
    root.do block

class Node:
  left := ?
  right := ?
  count /int

  constructor .left .right:
    if left is not string and left is not Node:
      throw "Invalid left"
    if right is not string and right is not Node:
      throw "Invalid right"
    count = (line-count left) + (line-count right)

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
    return dump_ "" ""

  dump_ prefix1/string prefix2/string -> string:
    result := ""
    if left is string:
      result += prefix1 + "\u{2571}" + left + "\n"
    else:
      result += left.dump_ (prefix1 + " ") (prefix1 + "\u{2571}")
    if right is string:
      result += prefix2 + "\u{2572}" + right + "\n"
    else:
      result += right.dump_ (prefix2 + "\u{2572}") (prefix2 + " ")
    return result

line-count thing -> int:
  if thing == null:
    return 0
  if thing is string:
    return 1
  return thing.count

line thing at/int -> string:
  while true:
    total-lines := line-count thing
    if not 0 <= at < total-lines: throw "Invalid at"
    if thing is string: return thing
    assert: thing is Node
    left-count := line-count thing.left
    if at < left-count:
      thing = thing.left
    else:
      thing = thing.right
      at -= left-count

join_ node divider/string -> string:
  if node == null: return ""
  if node is string: return node
  array := []
  node.do: array.add it
  return array.join divider

/**
 * Creates a collection that has the numbered lines in it.
 * $root is null, a string, or a Node.
 * 0-based $from, $to.  To is non-inclusive.
 */
range root from/int to/int:
  if root == null:
    if from != 0 or to != 0: throw "Invalid range"
    return null
  if root is string:
    if from != 0 or to != 1: throw "Invalid range $from-$to"
    return root
  // We can't use recursion because it might recurse too deep.
  l := null
  r := null
  self := root
  while true:
    if self is string:
      if from != 0 or to != 1: throw "Invalid range $from-$to"
      if l == null:
        if r == null:
          return self
        return Node self r
      if r == null:
        return Node l self
      return Node (Node l self) r
    if self is Node:
      if from == 0 and to == (line-count self):
        if l != null:
          if r != null:
            return Node l (Node self r)
          return Node l self
        if r != null:
          return Node self r
        return self
      before := line-count self.left
      after := line-count self.right
      left-overhang := before - from
      right-overhang := to - before
      if left-overhang < 0:
        assert: l == null
        from -= before
        to -= before
        self = self.right
      else if right-overhang < 0:
        assert: r == null
        self = self.left
      else if left-overhang == 0:
        self = self.right
        from -= before
        to -= before
      else if right-overhang == 0:
        self = self.left
      else if left-overhang < right-overhang:
        // Recurse on the short side to limit depth.
        new-l := range self.left from before
        l = (l == null) ? new-l : (Node l new-l)
        self = self.right
        from = 0
        to -= left-overhang
      else:
        // Recurse on the short side to limit depth.
        new-r := range self.right 0 right-overhang
        r = (r == null) ? new-r : (Node new-r r)
        self = self.left
        to -= right-overhang
