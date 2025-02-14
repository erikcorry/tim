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

is-command-char_ char/int? -> bool:
  if not char: return false
  if 'a' <= char <= 'z': return true
  if 'A' <= char <= 'Z': return true
  if char == '=': return true
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

  run-command input command/string [--on-error] -> Document:
    state := State current-line line-count this
    parser := CommandParser command state
    c/Command := parser.parse on-error
    from := c.from
    to := c.to
    command = c.command

    if command == "a": from = to
    left := Node.range root 0 from
    right := Node.range root to line-count
    old-lines := Node.range root from to

    // Print the range.
    if command == "p":
      do old-lines: print it
      current-line = to - 1
      return this  // No change to document.
    if command == "n":
      do old-lines: | line |
        print "$(from + 1)\t$line"
        from++
      current-line = to - 1
      return this  // No change to document.
    if command == "D":
      // Dump document tree.
      if old-lines is string:
        print old-lines
      else:
        print old-lines.dump_
      return this  // No change to document.
    if command == "d":
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

      lines.do:
        left = Node.append left it
      result := Document left right this
      next = result
      result.current-line = (Node.line-count left) - 1
      if result.current-line < 0: result.current-line = 0
      result.modified = true
      return result
    if command == "j":
      to-join := []
      do old-lines: to-join.add it
      replacement := to-join.join ""
      left = Node.append left replacement
      result := Document left right this
      next = result
      result.current-line = (Node.line-count left) - 1
      result.modified = true
      return result
    if command.starts-with "s" and command.size > 2:
      parts := parse-substitute command[1..] on-error
      re/regexp.RegExp := parts[0]
      substitution := parts[1]
      flags := parts[2]
      global-flag := parse-flag_ "g" flags: flags = it
      match-number := 1
      if not global-flag:
        match-number = parse-number-flag_ flags: flags = it
      if flags != "":
        on-error.call "Invalid flags: '$flags'"
        unreachable
      last-matched-line/int? := null
      line-no := from - 1
      lines := Node.substitute old-lines: | line/string |
        line-no++
        if not global-flag:
          match/regexp.Match? := nth-match_ re line match-number
          if match:
            last-matched-line = line-no
            output := ""
            if match.index != 0:
              output += line[..match.index]
            output += substitution.call match
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
            output += substitution.call match
            position = match.end-index
          if found:
            output += line[position..]
            last-matched-line = line-no
            output
          else:
            line
      result := Document (Node.append left lines) right this
      if last-matched-line:
        result.current-line = last-matched-line
      else:
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

DEFAULT-ADDRESS_ ::= {
  'a': ".",
  'c': ".,.",
  'd': ".,.",
  'g': "1,\$",
  'G': "1,\$",
  'i': ".",
  'j': ".,.+1",
  'k': ".",
  'l': ".,.",
  'm': ".,.",
  'n': ".,.",
  'p': ".,.",
  'r': "\$",
  's': ".,.",
  't': ".,.",
  'v': "1,\$",
  'V': "1,\$",
  'w': "1,\$",
  'z': ".+1",
  '=': "\$",
}

class State:
  current-line/int := ?
  line-count/int
  document/Document

  constructor .current-line .line-count .document:

class CommandParser:
  pos := 0
  line/string
  state/State

  constructor line/string .state:
    if line.size > 0 and is-command-char_ line[0]:
      this.line = (DEFAULT-ADDRESS_.get line[0] --if-absent=: "") + line
    else:
      this.line = line

  parse [on-error] -> Command:
    if consume '%':
      return Command.private_ 0 state.line-count line[pos..]
    from/int? := ?
    to/int? := ?
    if consume ';':
      from = state.current-line + 1
      to = parse-range-part
      if not to: to = state.line-count
    else if consume ',':
      from = 1
      to = parse-range-part
      if not to: to = state.line-count
    else:
      from = parse-range-part
      if consume ';':
        state.current-line = from - 1
        to = parse-range-part
        if not to: to = from
      else if consume ',':
        to = parse-range-part
        if not to: to = from
      else:
        to = from
    return Command.private_ (from ? from - 1 : null) to line[pos..]

  char -> int?:
    if pos >= line.size: return null
    return line[pos]

  consume c/int -> bool:
    if char == c:
      pos++
      return true
    return false

  on-digit -> bool:
    if pos >= line.size: return false
    return '0' <= line[pos] <= '9'

  parse-int -> int:
    start := pos
    while on-digit:
      pos++
    if pos == start: return 0
    return int.parse line[start..pos]

  parse-plus-part -> int:
    plus-part := 0
    if char == '-':
      while char == '-':
        plus-part--
        pos++
      if on-digit: plus-part -= parse-int - 1
    else if char == '+':
      while char == '+':
        plus-part++
        pos++
      if on-digit: plus-part += parse-int - 1
    return plus-part

  // Parses the range part and returns the 1-based literal line number.
  parse-range-part -> int?:
    base/int := ?
    if on-digit:
      base = parse-int
    else if consume '$':
      base = state.line-count
    else if consume '.':
      base = state.current-line + 1  // Add 1 because current-line is 0-based.
    else:
      if char == '+' or char == '-':
        base = state.current-line + 1
      else:
        return null
    return base + parse-plus-part

class Command:
  from/int?
  to/int?
  command/string

  constructor.private_ .from .to .command:

nth-match_ re/regexp.RegExp line/string n/int -> regexp.Match?:
  counter := 1
  re.all-matches line 0: | match/regexp.Match |
    if counter++ == n:
      return match
  return null

parse-flag_ character/string flags/string [update] -> bool:
  idx := flags.index-of character
  if idx == -1: return false
  update.call flags[..idx] + flags[idx + 1..]
  return true

parse-number-flag_ flags/string [update] -> int:
  for i := 0; i < flags.size; i++:
    if '1' <= flags[i] <= '9':
      j := i + 1
      for ; j < flags.size; j++:
        if not '0' <= flags[j] <= '9': break
      update.call flags[..i] + flags[j..]
      return int.parse flags[i..j]
  return 1

get-regexp-end s/string i/int --divider/int [on-error] -> int:
  after-backslash := false
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
  return i

parse-substitute s/string [on-error] -> List:
  divider := s[0]
  if divider >= 'A':
    on-error.call "Invalid regexp delimiter"
    unreachable
  i := get-regexp-end s 1 --divider=divider on-error

  re := s[1..i]

  repl /string := ?
  flags /string := ?
  backslash-found := false
  case-sensitive /bool := ?

  if i + 1 == s.size:
    repl = ""
    flags = ""
    case-sensitive = true
  else:
    // Quick parse of the replacement string to find its extent.
    start := i + 1
    post-backslash := false
    for i = start; i < s.size; i++:
      if post-backslash:
        post-backslash = false
      else if s[i] == '\\':
        post-backslash = true
        backslash-found = true
      else if s[i] == divider:
        break
    if post-backslash:
      on-error.call "Ends with backslash"
      unreachable
    repl = s[start..i]
    flags = (i == s.size) ? "" : s[i + 1 ..]
    case-sensitive = not (parse-flag_ "i" flags: flags = it)

  // Compile the regexp.
  parsed/regexp.RegExp? := null
  exception := catch:
    parsed = regexp.RegExp.ed re --case-sensitive=case-sensitive
  if exception:
    on-error.call "Invalid regular expression: $exception"
    unreachable
  number-of-captures := parsed.number-of-captures

  // Now we have parsed the regexp and know the number of captures we can parse
  // the replacement string for real.
  replacer /Lambda := ?
  if not backslash-found:
    replacer = :: repl
  else:
    replacer = parse-replace-string_ repl number-of-captures
  return [parsed, replacer, flags]

parse-replace-string_ repl/string number-of-captures/int -> Lambda:
  chars /List? := []
  capture-found := false
  after-backslash := false
  for i := 0 ; i < repl.size; i++:
    if after-backslash:
      after-backslash = false
      valid-capture := false
      j := i
      while j < repl.size and '0' <= repl[j] <= '9' and j - i < 10:
        j++
      if j != i:
        capture-number := int.parse repl[i..j]
        if 0 < capture-number <= number-of-captures:
          i = j - 1
          chars.add -capture-number
          capture-found = true
          valid-capture = true
      if not capture-found:
        chars.add repl[i]
      continue
    if repl[i] == '\\':
      after-backslash = true
      continue
    if chars: chars.add repl[i]
  if not capture-found:
    substitution := ByteArray chars.size: chars[it]
    str := substitution.to-string
    return :: str
  else:
    return construct-replace-function chars

construct-replace-function chars/List -> Lambda:
  // Always one more string than index.
  strings := []
  indexes := []
  start := 0
  for i := 0; i < chars.size; i++:
    if chars[i] < 0:
      substitution := ByteArray i - start: chars[start + it]
      strings.add substitution.to-string
      indexes.add chars[i]
      start = i + 1
  substitution := ByteArray chars.size - start: chars[start + it]
  strings.add substitution.to-string
  return :: | match/regexp.Match |
    result := []
    for i := 0; i < strings.size - 1; i++:
      result.add strings[i]
      result.add match[-indexes[i]]
    result.add strings[strings.size - 1]
    result.join ""  // Return value of lambda.
