import host.file
import host.pipe
import cli
import .tree

main args/List -> int:
  if args.size != 1:
    throw "Usage: ted <input file>"
  
  stream := (file.Stream.for-read args[0]).in

  document := Document.empty

  bytes := 0

  while line := stream.read-line:
    // While loading we modify the document in place.
    document.root = Node.append document.root line
    if document.root is BinaryNode:
      document.root = document.root.rebalance 20
    bytes += line.size + 1

  document.current-line = document.line-count - 1

  print bytes

  input := pipe.stdin.in

  while line := input.read-line:
    document = document.run-command line --on-error=: | message |
      print "? $message"
      continue

  return 0

is-decimal_ str/string -> bool:
  if str.size == 0: return false
  str.do:
    if it is not int: return false
    if not '0' <= it <= '9': return false
  return true

is-command-char_ char/int -> bool:
  if 'a' <= char <= 'z': return true
  if 'A' <= char <= 'Z': return true
  return false

class Document:
  // Null: Empty document.
  // String: Single-line document.
  // Node: Multi-line document.
  root := NullNode.instance
  previous /Document? := null
  next /Document?  := null
  current-line/int := 0

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

  line-count -> int:
    if root is NullNode: return 0
    if root is string: return 1
    return root.line-count

  line-at number/int -> string:
    if root is NullNode:
      throw "Empty document"
    if root is string: return root
    return root.line number

  static line-count_ thing -> int:
    if thing is string: return 1
    return thing.line-count

  insert lines at/int -> Document:
    if at == 0: return prepend lines
    line-count := line-count_ root
    if at == line-count: return append lines
    if not 0 < at < line-count: throw "Invalid at"
    left := Node.range root 0 at
    right := Node.range root at line-count
    result := Document (BinaryNode left (BinaryNode lines right)) this
    next = result
    return result

  do [block] -> none:
    if root is string:
      block.call root
      return
    root.do block

  /// Returns the rest of the $command, which starts with a letter.
  /// Calls the $on-error block with the start and end of the range.
  parse-comma-range command/string [on-error] [block] -> string?:
    parts := command.split --at-first ","
    assert: parts.size == 2
    l := parts[0]
    r := parts[1]
    command-start := 0
    while command-start < r.size and not is-command-char_ r[command-start]:
      command-start++
    command = r[command-start..]
    r = r[..command-start]
    from/int := parse-range-part l on-error
    to/int := parse-range-part --part-2 r on-error
    block.call from to
    return command

  parse-range-part part/string --part-2/bool=false [on-error] -> int:
    if part.size == 0: return 0
    if is-decimal_ part:
      return int.parse part
    if part == "\$":
      return line-count
    if part == ".":
      return current-line
    if part.starts-with "+":
      result := current-line + 1
      part = part[1..]
      if is-decimal_ part:
        return result - 1 + (int.parse part)
      while part.starts-with "+":
        part = part[1..]
        result++
      if part != "":
        on-error.call "Invalid range part '$part'"
        unreachable
      return result
    if part.starts-with "-":
      result := current-line - 1
      part = part[1..]
      if is-decimal_ part:
        return result + 1 - (int.parse part)
      while part.starts-with "-":
        part = part[1..]
        result--
      if part != "":
        on-error.call "Invalid range part '$part'"
        unreachable
      return result
    on-error.call "Invalid range part '$part'"
    unreachable

  run-command command/string [--on-error] -> Document:
    from := current-line
    to := current-line
    if is-decimal_ command:
      index := int.parse command
      if not 1 <= index <= line-count:
        on-error.call "? Invalid index"
        unreachable
      else:
        current-line = index - 1  // Internal lines are 0-based.
        print
            line-at current-line
        // Setting the current line does not create a new version of the
        // document.
        return this
    else if (command.index-of ",") != -1:
      command = parse-comma-range command on-error: | f/int t/int |
        from = f
        to = t
      // For now only support p (print command).
      (Node.range root from to).do: | line |
        print line
      return this
    else:
      on-error.call ""
      unreachable
