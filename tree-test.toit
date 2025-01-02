import expect show *
import .tree

main:
  tree-test

tree-test:
  document := Document.empty
  expect document is Document

  document = document.append "a"
  document = document.append "b"
  document = document.append "c"
  document2 := document.append "d"

  print
      document.dump_
  print
      document2.dump_

  expect-equals "a,b,c" (join document)
  expect-equals "a,b,c,d" (join document2)

  expect-equals "a,b,c" (join (Document.range document.root 0 3))
  expect-equals "a,b,c" (join (Document.range document2.root 0 3))
  expect-equals "b,c,d" (join (Document.range document2.root 1 4))

  2.repeat:
    document = document.prepend "a$it"

  expect-equals "a1,a0,a,b,c" (join document)

  2.repeat:
    document = document.append "b$it"

  expect-equals "a1,a0,a,b,c,b0,b1" (join document)

  3.repeat:
    document = document.prepend "c$it"

  expect-equals "c2,c1,c0,a1,a0,a,b,c,b0,b1" (join document)

  3.repeat:
    document = document.append "d$it"

  expect-equals "c2,c1,c0,a1,a0,a,b,c,b0,b1,d0,d1,d2" (join document)

  2.repeat:
    document = document.prepend "e$it"
    document = document.append "f$it"

  expect-equals "e1,e0,c2,c1,c0,a1,a0,a,b,c,b0,b1,d0,d1,d2,f0,f1" (join document)

  expect-equals "e1,e0,c2,c1,c0,a1,a0,a,b,c,b0,b1,d0,d1,d2,f0,f1" (join (Document.range document.root 0 document.line-count))
  expect-equals "e1,e0,c2,c1,c0" (join (Document.range document.root 0 5))
  expect-equals "c2,c1,c0" (join (Document.range document.root 2 5))
  expect-equals "c2,c1,c0,a1,a0,a" (join (Document.range document.root 2 8))

  print
      document.dump_

  400000.repeat:
    document2 = document2.append "x$it"
  
join document -> string:
  array := []
  document.do: array.add it
  return array.join ","
