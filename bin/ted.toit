import dartino-regexp.regexp
import host.file
import host.pipe
import cli
import .tree

main args/List -> int:
  if args.size > 0 and args[0] == "-l":
    args = args[1..]
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
    document = document.run-command input line --on-error=: | message |
      print "? $message"
      continue

  if document.modified: print "?"  // Emulate exiting question mark of ed.
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
  modified := false

  dump_ -> string:
    if root is string: return root
    return root.dump_

  constructor .root .previous:
    modified = previous ? previous.modified : false

  constructor left right .previous:
    modified = previous ? previous.modified : false
    if left is NullNode:
      root = right
    else if right is NullNode:
      root = left
    else:
      root = BinaryNode left right

  static empty -> Document:
    return empty_

  static empty_ := Document NullNode.instance null

  append lines -> Document:
    if lines is not string and lines is not Node:
      throw "Invalid lines"
    if lines is NullNode: return this
    result /Document := Document root lines this
    next = result
    if result.root is Node: result.root = result.root.rebalance 20
    return result

  prepend lines -> Document:
    if lines is not string and lines is not Node:
      throw "Invalid lines"
    if lines is NullNode: return this
    result /Document := Document lines root this
    next = result
    if result.root is Node: result.root = result.root.rebalance 20
    return result

  line-count -> int:
    if root is string: return 1
    return root.line-count

  line-at number/int -> string:
    if root is NullNode:
      throw "Empty document"
    if root is string: 
      if number != 0: throw "Invalid line number"
      return root
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
    result := Document left (BinaryNode lines right) this
    next = result
    return result

  do node [block] -> none:
    if node is string:
      block.call node
      return
    node.do block

  /**
  Calls the $block with the start and end of the range.
  Arguments to the block are 0-based and do not include the last line, in
    accordance with modern usage.  Since the ed command language is not written
    like this, some adjustments are made.
  */
  parse-comma-range address/string [on-error] [block]:
    parts := address.split --at-first ","
    assert: parts.size == 2
    l := parts[0]
    r := parts[1]
    from/int := l == "" ? 1 : (parse-range-part l on-error)
    to/int := r == "" ? line-count : (parse-range-part r on-error)
    block.call (from - 1) to

  // Parses the range part and returns the 1-based literal line number.
  parse-range-part part/string [on-error] -> int:
    plus := part.index-of "+"
    if plus == -1: plus = part.index-of "-"
    plus-part := ""
    if plus != -1:
      plus-part = part[plus ..]
      part = part[..plus]
    result/int := ?
    if part.size == 0:
      result = current-line + 1
    else if is-decimal_ part:
      result = int.parse part
    else if part == "\$":
      result = line-count
    else if part == ".":
      result = current-line + 1  // Add 1 because current-line is 0-based.
    else:
      on-error.call "Invalid range part '$part'"
      unreachable
    if plus-part.starts-with "+":
      result++
      plus-part = plus-part[1..]
      if is-decimal_ plus-part:
        result += (int.parse plus-part) - 1
        plus-part = ""
      while plus-part.starts-with "+":
        plus-part = plus-part[1..]
        result++
      if plus-part != "":
        on-error.call "Invalid range part '$plus-part'"
        unreachable
    else if plus-part.starts-with "-":
      result--
      plus-part = plus-part[1..]
      if is-decimal_ plus-part:
        result -= -1 + (int.parse plus-part)
        plus-part = ""
      while plus-part.starts-with "-":
        plus-part = plus-part[1..]
        result--
      if plus-part != "":
        on-error.call "Invalid range part '$plus-part'"
        unreachable
    return result

  run-command input command/string [--on-error] -> Document:
    from := current-line
    to := current-line + 1
    command-start := 0
    while command-start < command.size and not is-command-char_ command[command-start]:
      command-start++
    address := command[..command-start]
    command = command[command-start..]
    lowest-index := (command.starts-with "a") ? 0 : 1
    has-comma /bool := (address.index-of ",") != -1
    if has-comma:
      parse-comma-range address on-error: | f/int t/int |
        from = f
        to = t
    else if address == ";":
      from = current-line
      to = line-count
    else if address != "":
      from = (parse-range-part address on-error) - 1
      to = from + 1

    // Print the range.
    if command == "p":
      do (Node.range root from to): | line |
        print line
      current-line = to - 1
      return this  // No change to document.
    if command == "n":
      do (Node.range root from to): | line |
        print "$(from + 1)\t$line"
        from++
      current-line = to - 1
      return this  // No change to document.
    if command == "d":
      left := from < 1 ? NullNode.instance : (Node.range root 0 from)
      right := to >= line-count ? NullNode.instance : (Node.range root to line-count)
      result := Document left right this
      next = result
      result.current-line = Node.line-count left
      if right is NullNode: result.current-line--
      result.modified = true
      return result
    if command == "a" or command == "c":
      lines := []
      while line := input.read-line:
        if line == ".":
          break
        lines.add line
      if command == "a": from = to
      left := from < 1 ? NullNode.instance : (Node.range root 0 from)
      right := to >= line-count ? NullNode.instance : (Node.range root to line-count)
      
      lines.do:
        left = Node.append left it
      result := Document left right this
      next = result
      result.current-line = Node.line-count left
      if right is NullNode: result.current-line--
      result.modified = true
      return result
    if command.starts-with "s" and command.size > 2:
      parts := parse-substitute command[1..] on-error
      re/regexp.RegExp? := null
      exception := catch:
        re = regexp.RegExp.ed parts[0]
      if exception:
        on-error.call "Invalid regular expression: $exception"
        unreachable
      substitution := parts[1]
      flags := parts[2]
      if flags != "" and flags != "g":
        on-error.call "Invalid flags: '$flags'"
        unreachable
      left := from < 1 ? NullNode.instance : (Node.range root 0 from)
      right := to >= line-count ? NullNode.instance : (Node.range root to line-count)
      old-lines := Node.range root from to
      at-least-one-match := false
      lines := Node.substitute old-lines: | line/string |
        if flags == "":
          match/regexp.Match? := re.first-matching line
          if match:
            at-least-one-match = true
            output := ""
            if match.index != 0:
              output += line[..match.index]
            output += substitution
            if match.end-index != line.size:
              output += line[match.end-index..]
            output
          else:
            line
        else:  // Global substitution.
          output := ""
          position := 0
          found/bool := re.all-matches line 0: | match/regexp.Match |
            output += line[position .. match.index]
            output += substitution
            position = match.end-index
          if found:
            output += line[position..]
            at-least-one-match = true
            output
          else:
            line
      result := Document (Node.append left lines) right this
      if not at-least-one-match:
        on-error.call "No substitution"
      result.modified = true
      return result
    if command == "":
      // Just moves to the numbered line and prints it.
      current-line = to - 1  // Internal lines are 0-based.
      print
          line-at current-line
      // Setting the current line does not create a new version of the
      // document.
      return this

    on-error.call "Unknown command: '$command'"
    unreachable

parse-substitute s/string [on-error] -> List:
  divider := s[0]
  if divider >= 'A':
    on-error.call "Invalid regexp delimiter"
    unreachable
  after-backslash := false
  i := 1
  for ; i < s.size; i++:
    if after-backslash:
      after-backslash = false
      continue
    if s[i] == '\\':
      after-backslash = true
      continue
    if s[i] == divider:
      break
  if i == s.size:
    on-error.call "No closing delimiter"
    unreachable
  re := s[1..i]
  if i + 1 == s.size: return [re, ""]
  chars /List? := null
  start := i + 1
  for i = start ; i < s.size; i++:
    if after-backslash:
      after-backslash = false
      chars.add s[i]
      continue
    if s[i] == '\\':
      after-backslash = true
      if not chars:
        chars = List (i - start): s[start + it]
      continue
    if s[i] == divider:
      break
    if chars: chars.add s[i]
  flags := (i + 1 > s.size) ? "" :  s[i + 1 ..]
  if chars:
    substitution := ByteArray chars.size: chars[it]
    return [re, substitution.to-string, flags]
  return [re, s[start..i], flags]
