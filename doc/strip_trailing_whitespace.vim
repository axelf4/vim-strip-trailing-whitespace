*strip_trailing_whitespace.txt*	For Vim version 8.2

Removes trailing whitespace from modified lines on save.

Some filetypes have significant trailing whitespace. An autocommand is
defined in the "strip_trailing_whitespace_filetype" group that sets
|b:strip_trailing_whitespace_enabled| to "0" for Markdown and diff files, and
"1" for other filetypes. To disable: >
    autocmd! strip_trailing_whitespace_filetype

==============================================================================

						*:StripTrailingWhitespace*
:[range]StripTrailingWhitespace
		Remove trailing whitespace from [range] lines (default all
		lines).

					*b:strip_trailing_whitespace_enabled*
b:strip_trailing_whitespace_enabled
		Per-buffer boolean toggle.

					*g:strip_trailing_whitespace_max_lines*
g:strip_trailing_whitespace_max_lines
		Maximum number of modified lines with trailing whitespace to
		keep track of before falling back to stripping the entire
		file.
		The default ensures the recursion depth limit won't be hit.


 vim:tw=78:ts=8:noet:ft=help:norl:
