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

  2.repeat:
    document = document.prepend "a$it"

  2.repeat:
    document = document.append "b$it"

  3.repeat:
    document = document.prepend "c$it"

  3.repeat:
    document = document.append "d$it"

  5.repeat:
    document = document.prepend "e$it"
    document = document.append "f$it"

  print
      document.dump_

  800000.repeat:
    document2 = document2.append "x$it"
    //print
        //document2.dump_
  
join document divider/string -> string:
  array := []
  document.do: array.add it
  return array.join divider
