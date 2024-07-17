[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>

## Lua Self-Generating Code via Genetic Algorithm

Requires my lua-parser, lua-ext, and the LuaFileSystem projects.

Starts with an empty function.

Applies single mutations to the AST of the function.

Does your typical genetic algorithm thing.

Comes up with a solution sometimes.

Capable of outputting family trees in GraphViz Dot format.

Usage:

1) mkdir pop
2) cp 0.lua pop
3) uncomment a fitness function of your choice inside of gen.lua
4a) ./gen.lua <# of iterations>
or 4b) ./gen.lua forever

To reset: ./gen.lua reset

To create a family tree: ./gen.lua maketree
(requires graphviz's 'dot' to be installed)

Example of a family tree solving the sine problem:

![sine problem example](https://cdn.rawgit.com/thenumbernine/lua-selfmodify/master/examples/familytree.svg)
