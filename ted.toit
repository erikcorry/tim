import host.file
import host.pipe
import cli
import .tree as tree

main args/List -> int:
  if args.size != 1:
    throw "Usage: ted <input file>"
  
  stream := (file.Stream.for-read args[0]).in

  document := tree.Document.empty

  bytes := 0

  while line := stream.read-line:
    document = document.append line
    bytes += line.size + 1

  current-line := document.line-count - 1

  print bytes

  input := pipe.stdin.in


  while line := input.read-line:
    if is-decimal line:
      index := int.parse line
      if not 1 <= index <= document.line-count:
        print "? Invalid index"
      else:
        current-line = index - 1  // Internal lines are 0-based.
        print
            document.line current-line
    else:
      print "?"

  return 0

is-decimal str/string -> bool:
  if str.size == 0: return false
  str.do:
    if it is not int: return false
    if not '0' <= it <= '9': return false
  return true
