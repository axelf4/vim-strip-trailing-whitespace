# vim-strip-trailing-whitespace
![](https://github.com/axelf4/vim-strip-trailing-whitespace/workflows/CI/badge.svg)

Vim plugin that removes trailing whitespace
 * **from modified lines:** Should not introduce extraneous changes into the diff, even when editing faulty files.
 
   For fixing up the whole file the command `:StripTrailingWhitespace` is provided.
 * **on save:** Lines changing under you feet breaks any flow and is a compatibility hazard.
 
Achieved by maintaining a set of all edited lines with trailing whitespace,
backed by a Splay tree where children store line number offsets.

*Vim support: requires Vim 8.2+*
