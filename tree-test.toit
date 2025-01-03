import expect show *
import .tree

main:
  tree-test

tree-test:
  tree/any := NullNode.instance
  expect tree is Node

  tree = Node.append tree "a"
  tree = Node.append tree "b"
  tree = Node.append tree "c"
  tree2/any := Node.append tree "d"

  print
      tree.dump_
  print
      tree2.dump_

  expect-equals "a,b,c" (join tree)
  expect-equals "a,b,c,d" (join tree2)

  expect-equals "a,b,c" (join (Node.range tree 0 3))
  expect-equals "a,b,c" (join (Node.range tree2 0 3))
  expect-equals "b,c,d" (join (Node.range tree2 1 4))

  2.repeat:
    tree = Node.prepend tree "a$it"
    tree = tree.rebalance (tree.depth - 1)

  expect-equals "a1,a0,a,b,c" (join tree)

  2.repeat:
    tree = Node.append tree "b$it"
    tree = tree.rebalance (tree.depth - 1)

  expect-equals "a1,a0,a,b,c,b0,b1" (join tree)

  3.repeat:
    tree = Node.prepend tree "c$it"
    tree = tree.rebalance (tree.depth - 1)

  expect-equals "c2,c1,c0,a1,a0,a,b,c,b0,b1" (join tree)

  3.repeat:
    tree = Node.append tree "d$it"
    tree = tree.rebalance (tree.depth - 1)

  expect-equals "c2,c1,c0,a1,a0,a,b,c,b0,b1,d0,d1,d2" (join tree)

  2.repeat:
    tree = Node.prepend tree "e$it"
    tree = Node.append tree "f$it"
    tree = tree.rebalance (tree.depth - 1)

  expect-equals "e1,e0,c2,c1,c0,a1,a0,a,b,c,b0,b1,d0,d1,d2,f0,f1" (join tree)

  expect-equals "e1,e0,c2,c1,c0,a1,a0,a,b,c,b0,b1,d0,d1,d2,f0,f1" (join (Node.range tree 0 tree.line-count))
  expect-equals "e1,e0,c2,c1,c0" (join (Node.range tree 0 5))
  expect-equals "c2,c1,c0" (join (Node.range tree 2 5))
  expect-equals "c2,c1,c0,a1,a0,a" (join (Node.range tree 2 8))

  print
      tree.dump_

  400000.repeat:
    if it & 0xfff == 0: print it
    tree2 = Node.append tree2 "x$it"
    tree2 = tree2.rebalance (tree2.depth - 1)

  print "Depth $tree2.depth"
  
join node -> string:
  array := []
  node.do: array.add it
  return array.join ","
