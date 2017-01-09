lua self-generating code

requires my lua-parser, lua-ext, and the LuaFileSystem projects

starts with an empty function

applies single mutations to the AST of the function

does your typical genetic algorithm thing

comes up with a solution sometimes

capable of outputting family trees in GraphViz Dot format

usage:

1) mkdir pop
2) cp 0.lua pop
3) uncomment a fitness function of your choice inside of gen.lua
4a) ./gen.lua <# of iterations>      
or 4b) ./gen.lua forever

to reset: ./gen.lua reset

to create a family tree: ./gen.lua maketree 
(requires graphviz's 'dot' to be installed)

Example of a family tree solving the sine problem:

![sine problem example](https://cdn.rawgit.com/thenumbernine/lua-selfmodify/master/examples/familytree.svg)
