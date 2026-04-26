" Vim plugin that removes trailing whitespace from modified lines on save
let s:save_cpo = &cpo | set cpo&vim

if exists('g:loaded_strip_trailing_whitespace') | finish | endif
let g:loaded_strip_trailing_whitespace = 1

command -bar -range=% StripTrailingWhitespace keeppatterns <line1>,<line2>substitute/\s\+$//e

if !exists('g:strip_trailing_whitespace_max_lines')
	" The maximum number of modified lines with trailing whitespace to keep
	" track of before falling back to stripping the entire file.
	let g:strip_trailing_whitespace_max_lines = &maxfuncdepth - 5
endif

function s:RotateRight(n) abort
	let x = a:n.left
	let a:n.left = x.right
	let x.right = a:n
	let x.key += a:n.key
	let a:n.key -= x.key
	if a:n.left isnot v:null | let a:n.left.key -= a:n.key | endif
	return x
endfunction

function s:RotateLeft(n) abort
	let x = a:n.right
	let a:n.right = x.left
	let x.left = a:n
	let x.key += a:n.key
	let a:n.key -= x.key
	if a:n.right isnot v:null | let a:n.right.key -= a:n.key | endif
	return x
endfunction

" Return the number of nodes in tree {n}.
let s:NodeCount = {n -> n is v:null ? 0 : 1 + s:NodeCount(n.left) + s:NodeCount(n.right)}

" Splay {key} in the tree rooted at the node {n}.
"
" If a node with that key exists, it is splayed to the root of the tree. If it
" does not, the last node along the search path for the key is splayed to the
" root.
function s:Splay(n, key) abort
	let n = a:n
	if n is v:null | return v:null | endif

	let key = a:key - n.key
	if key < 0
		if n.left is v:null | return n | endif " Key is not in tree, so we are done

		let key -= n.left.key
		if key < 0
			let n.left.left = s:Splay(n.left.left, key)
			let n = s:RotateRight(n)
		elseif key > 0
			let n.left.right = s:Splay(n.left.right, key)
			if n.left.right isnot v:null
				let n.left = s:RotateLeft(n.left)
			endif
		endif

		return n.left is v:null ? n : s:RotateRight(n)
	elseif key > 0
		if n.right is v:null | return n | endif " Key is not in tree, so we are done

		let key -= n.right.key
		if key < 0
			let n.right.left = s:Splay(n.right.left, key)
			if n.right.left isnot v:null
				let n.right = s:RotateRight(n.right)
			endif
		elseif key > 0
			let n.right.right = s:Splay(n.right.right, key)
			let n = s:RotateLeft(n)
		endif

		return n.right is v:null ? n : s:RotateLeft(n)
	endif
	return n
endfunction

function s:Put(root, key) abort
	if a:root is v:null | return {'key': a:key, 'left': v:null, 'right': v:null} | endif
	let root = s:Splay(a:root, a:key) " Splay key to root
	" Insert new node at root
	let cmp = a:key - root.key
	if cmp < 0
		let n = {'key': a:key, 'left': root.left, 'right': root}
		let root.left = v:null
		if n.left isnot v:null | let n.left.key += root.key - n.key | endif
		let n.right.key -= n.key
		return n
	elseif cmp > 0
		let n = {'key': a:key, 'left': root, 'right': root.right}
		let root.right = v:null
		if n.right isnot v:null | let n.right.key += root.key - n.key | endif
		let n.left.key -= n.key
		return n
	endif
	return root
endfunction

" Remove keys in the range [{min}, {max}) from {root}.
"
" Does modified Hibbard deletion.
function s:RemoveRange(root, min, max) abort
	if a:root is v:null | return [v:null, 0] | endif
	let root = s:Splay(a:root, a:min) " Splay around lower bound
	let cnt = 0
	let right = root.right
	if right isnot v:null | let right.key += root.key | endif
	let root.right = v:null

	" Remove root if in range
	if a:min <= root.key && root.key < a:max
		if root.left isnot v:null | let root.left.key += root.key | endif
		let root = root.left
		let cnt += 1
	endif

	if right isnot v:null
		let right = s:Splay(right, a:max) " Splay around upper bound
		let cnt += s:NodeCount(right.left)
		let right.left = v:null

		" If root of right subtree is in range: Remove it
		if right.key < a:max
			if right.right isnot v:null | let right.right.key += right.key | endif
			let right = right.right
			let cnt += 1
		endif

		if root is v:null
			let root = right
		elseif right isnot v:null
			let root = s:Splay(root, 1 / 0) " Move rightmost to root
			let right.key -= root.key
			let root.right = right
		endif
	endif

	return [root, cnt]
endfunction

" Whether currently deleting whitespace. (Ignore changes while that is the case.)
let s:is_stripping = 0

function StripTrailingWhitespaceListener(bufnr, start, end, added, changes) abort
	let [root, cnt] = [getbufvar(a:bufnr, 'stw_root'), getbufvar(a:bufnr, 'stw_count')]
	if s:is_stripping || cnt > g:strip_trailing_whitespace_max_lines | return | endif

	for change in a:changes
		let [lnum, end, added] = [change.lnum, change.end, change.added]
		" Remove existing in range
		if lnum < end
			let [root, num_removed] = s:RemoveRange(root, lnum, end)
			let cnt -= num_removed
		endif

		" Adjust line numbers
		if root isnot v:null
			let root = s:Splay(root, end)
			if root.key >= end
				let root.key += added
				if root.left isnot v:null | let root.left.key -= added | endif
			elseif root.right isnot v:null
				let root.right.key += added
			endif
		endif

		" (Re-)Add lines in range with trailing whitespace
		for i in range(lnum, end + added - 1)
			if getbufoneline(a:bufnr, i) !~# '\s$' | continue | endif
			let new_root = s:Put(root, i)
			let cnt += new_root isnot root
			let root = new_root

			if cnt > g:strip_trailing_whitespace_max_lines
				" Max count since unable to recommence (may have missed changes)
				call setbufvar(a:bufnr, 'stw_root', v:null)
				call setbufvar(a:bufnr, 'stw_count', 1 / 0)
				echohl WarningMsg | echo 'Falling back to stripping entire file: Too many TWS'
							\ '(use `:let b:strip_trailing_whitespace_enabled = 0` to skip)' | echohl None
				return
			endif
		endfor
	endfor
	call setbufvar(a:bufnr, 'stw_root', root)
	call setbufvar(a:bufnr, 'stw_count', cnt)
endfunction

function s:OnBufEnter() abort
	if exists('b:stw_root') | return | endif
	let [b:stw_root, b:stw_count] = [v:null, 0]
	if has('nvim')
		" Parsing the lua Ex command can fail on broken Vim <8.2.1908 installs
		execute 'lua vim.api.nvim_buf_attach(0, false, {
					\ on_lines = function(_, bufnr, _, firstline, lastline, new_lastline)
					\ vim.api.nvim_call_function("StripTrailingWhitespaceListener", {bufnr, firstline + 1, lastline + 1, new_lastline - lastline,
					\ {{lnum = firstline + 1, ["end"] = lastline + 1, added = new_lastline - lastline, col = 1}}})
					\ end, })'
	else
		call listener_add('StripTrailingWhitespaceListener')
	endif
endfunction

" Recursively strip lines in the specified tree.
function s:StripTree(n, offset) abort
	silent execute (a:n.key + a:offset) 'StripTrailingWhitespace'
	if a:n.left isnot v:null | call s:StripTree(a:n.left, a:offset + a:n.key) | endif
	if a:n.right isnot v:null | call s:StripTree(a:n.right, a:offset + a:n.key) | endif
endfunction

function s:OnWrite() abort
	if !get(b:, 'strip_trailing_whitespace_enabled', 1) | return | endif
	if !has('nvim') | call listener_flush() | endif

	let s:is_stripping = 1
	let save_cursor = getcurpos()
	try
		if b:stw_count > g:strip_trailing_whitespace_max_lines
			silent StripTrailingWhitespace
		else
			if b:stw_root isnot v:null | call s:StripTree(b:stw_root, 0) | endif
			let [b:stw_root, b:stw_count] = [v:null, 0]
		endif
	finally
		call setpos('.', save_cursor)
		let s:is_stripping = 0
	endtry
endfunction

augroup strip_trailing_whitespace
	autocmd!
	autocmd BufEnter * call s:OnBufEnter()
	autocmd BufWritePre * call s:OnWrite()
augroup END

augroup strip_trailing_whitespace_filetype
	autocmd!
	autocmd FileType * let b:strip_trailing_whitespace_enabled = index(['diff', 'markdown'],
				\ &filetype) == -1
augroup END

let &cpo = s:save_cpo | unlet s:save_cpo
