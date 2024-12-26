import .tree

main:
  tree-test

tree-test:
  document := Document.empty
  assert: document is Document

  document = document.append "a"
  document = document.append "b"
  document = document.append "c"
  document2 := document.append "d"

  print
      document.dump_
  print
      document2.dump_

  assert: "a,b,c" == (join document ",")
  assert: "a,b,c,d" == (join document2 ",")

  assert: "a,b,c" == (join (range document.root 0 3) ",")
  assert: "a,b,c" == (join (range document2.root 0 3) ",")
  assert: "b,c,d" == (join (range document2.root 1 4) ",")
  
  4.repeat:
    document2.rebase it
    print "Rebased on $it:"
    print document2.dump_
    assert: "a,b,c,d" == (join document2 ",")

join document divider/string -> string:
  array := []
  document.do: array.add it
  return array.join divider
