" Vim plugin that removes trailing whitespace from modified lines on save
let s:save_cpo = &cpo | set cpo&vim

" Only load the plugin once
if exists('g:loaded_strip_trailing_whitespace')
    finish
endif
let g:loaded_strip_trailing_whitespace = 1

" Strip trailing whitespace
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
	let [n, key] = [a:n, a:key]
	if n is v:null | return v:null | endif

	let key -= n.key
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
	else
		return n
	endif
endfunction

function s:Put(key) abort
	if b:stw_root is v:null
		let [b:stw_root, b:stw_count] = [{'key': a:key, 'left': v:null, 'right': v:null}, 1]
		return
	endif

	let b:stw_root = s:Splay(b:stw_root, a:key) " Splay key to root
	" Insert new node at root
	let cmp = a:key - b:stw_root.key
	if cmp < 0
		let n = {'key': a:key, 'left': b:stw_root.left, 'right': b:stw_root}
		let b:stw_root.left = v:null
		if n.left isnot v:null | let n.left.key += b:stw_root.key - n.key | endif
		let n.right.key -= n.key
		let b:stw_root = n
		let b:stw_count += 1
	elseif cmp > 0
		let n = {'key': a:key, 'left': b:stw_root, 'right': b:stw_root.right}
		let b:stw_root.right = v:null
		if n.right isnot v:null | let n.right.key += b:stw_root.key - n.key | endif
		let n.left.key -= n.key
		let b:stw_root = n
		let b:stw_count += 1
	endif
endfunction

" Remove keys in the range [{min}, {max}) from the tree.
"
" Does modified Hibbard deletion.
function s:RemoveRange(min, max) abort
	if b:stw_root is v:null | return | endif
	let b:stw_root = s:Splay(b:stw_root, a:min) " Splay around lower bound
	let right = b:stw_root.right
	if right isnot v:null | let right.key += b:stw_root.key | endif
	let b:stw_root.right = v:null

	" Remove root if in range
	if a:min <= b:stw_root.key && b:stw_root.key < a:max
		if b:stw_root.left isnot v:null | let b:stw_root.left.key += b:stw_root.key | endif
		let b:stw_root = b:stw_root.left
		let b:stw_count -= 1
	endif

	if right isnot v:null
		let right = s:Splay(right, a:max) " Splay around upper bound
		let b:stw_count -= s:NodeCount(right.left)
		let right.left = v:null

		" If root of right subtree is in range: Remove it
		if right.key < a:max
			if right.right isnot v:null | let right.right.key += right.key | endif
			let right = right.right
			let b:stw_count -= 1
		endif

		if b:stw_root is v:null
			let b:stw_root = right
		elseif right isnot v:null
			let b:stw_root = s:Splay(b:stw_root, 1 / 0) " Move rightmost to root
			let right.key -= b:stw_root.key
			let b:stw_root.right = right
		endif
	endif
endfunction

" Whether in the process of deleting whitespace.
"
" Ignore changes while that is the case.
let s:is_stripping = 0

function StripTrailingWhitespaceListener(bufnr, start, end, added, changes) abort
	if s:is_stripping || b:stw_count > g:strip_trailing_whitespace_max_lines | return | endif

	" Remove existing in range
	if a:start < a:end | call s:RemoveRange(a:start, a:end) | endif

	" Adjust line numbers
	if b:stw_root isnot v:null
		let b:stw_root = s:Splay(b:stw_root, a:end)
		if b:stw_root.key >= a:end
			let b:stw_root.key += a:added
			if b:stw_root.left isnot v:null | let b:stw_root.left.key -= a:added | endif
		elseif b:stw_root.right isnot v:null
			let b:stw_root.right.key += a:added
		endif
	endif

	" (Re-)Add lines in range with trailing whitespace
	for lnum in range(a:start, a:end + a:added - 1)
		let has_trailing_ws = getline(lnum) =~# '\s$'
		if has_trailing_ws
			call s:Put(lnum)

			if b:stw_count > g:strip_trailing_whitespace_max_lines
				" Max count since unable to recommence (might have missed changes)
				let [b:stw_root, b:stw_count] = [v:null, 1 / 0]
				echohl WarningMsg | echo 'Falling back to stripping entire file: Too many TWS'
							\ '(use `:let b:strip_trailing_whitespace_enabled = 0` to skip)' | echohl None
				break
			endif
		endif
	endfor
endfunction

function s:OnBufEnter() abort
	if exists('b:stw_root') | return | endif
	let [b:stw_root, b:stw_count] = [v:null, 0]
	if has('nvim')
		lua vim.api.nvim_buf_attach(0, false, {
					\ on_lines = function(_, bufnr, _, firstline, lastline, new_lastline)
					\ vim.api.nvim_call_function("StripTrailingWhitespaceListener", {bufnr, firstline + 1, lastline + 1, new_lastline - lastline, {}})
					\ end, })
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
