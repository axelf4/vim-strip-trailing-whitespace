" Vim plugin that removes trailing whitespace from modified lines on save
scriptversion 4

" Strip trailing whitespace
command -bar -range=% StripTrailingWhitespace keeppatterns <line1>,<line2>substitute/\s\+$//e

const s:null = {} " Sentinel value indicating null.

function s:RotateRight(n) abort
	let x = a:n.left
	let a:n.left = x.right
	let x.right = a:n
	let x.key += a:n.key
	let a:n.key -= x.key
	if a:n.left isnot s:null | let a:n.left.key -= a:n.key | endif
	return x
endfunction

function s:RotateLeft(n) abort
	let x = a:n.right
	let a:n.right = x.left
	let x.left = a:n
	let x.key += a:n.key
	let a:n.key -= x.key
	if a:n.right isnot s:null | let a:n.right.key -= a:n.key | endif
	return x
endfunction

" Splay {key} in the tree rooted at the node {n}.
"
" If a node with that key exists, it is splayed to the root of the tree. If it
" does not, the last node along the search path for the key is splayed to the
" root.
function s:Splay(n, key) abort
	let [n, key] = [a:n, a:key]
	if n is s:null | return s:null | endif

	let key -= n.key
	if key < 0
		if n.left is s:null | return n | endif " Key is not in tree, so we are done

		let key -= n.left.key
		if key < 0
			let n.left.left = s:Splay(n.left.left, key)
			let n = s:RotateRight(n)
		elseif key > 0
			let n.left.right = s:Splay(n.left.right, key)
			if n.left.right isnot s:null
				let n.left = s:RotateLeft(n.left)
			endif
		endif

		return n.left is s:null ? n : s:RotateRight(n)
	elseif key > 0
		if n.right is s:null | return n | endif " Key is not in tree, so we are done

		let key -= n.right.key
		if key < 0
			let n.right.left = s:Splay(n.right.left, key)
			if n.right.left isnot s:null
				let n.right = s:RotateRight(n.right)
			endif
		elseif key > 0
			let n.right.right = s:Splay(n.right.right, key)
			let n = s:RotateLeft(n)
		endif

		return n.right is s:null ? n : s:RotateLeft(n)
	else
		return n
	endif
endfunction

function s:Put(key) abort
	if b:root is s:null
		" Splay key to root
		let b:root = #{key: a:key, left: s:null, right: s:null}
		return
	endif

	let b:root = s:Splay(b:root, a:key)

	" Insert new node at root
	let cmp = a:key - b:root.key
	if cmp < 0
		let n = #{key: a:key, left: b:root.left, right: b:root}
		let b:root.left = s:null
		if n.left isnot s:null | let n.left.key += b:root.key - n.key | endif
		let n.right.key -= n.key
		let b:root = n
	elseif cmp > 0
		let n = #{key: a:key, left: b:root, right: b:root.right}
		let b:root.right = s:null
		if n.right isnot s:null | let n.right.key += b:root.key - n.key | endif
		let n.left.key -= n.key
		let b:root = n
	else
		" Duplicate key
	endif
endfunction

function s:Remove(key) abort
	if b:root is s:null | return | endif " Empty tree
	let b:root = s:Splay(b:root, a:key)
	" Check if key was in the tree
	if a:key != b:root.key | return | endif

	if b:root.left is s:null
		let b:root = b:root.right
		let b:root.key += a:key
	else
		let x = b:root.right
		let b:root = b:root.left
		let x.key -= b:root.key
		call s:Splay(b:root, a:key)
		let b:root.key += a:key
		let b:root.right = x
	endif
endfunction

" Removes the specified range of keys from the tree.
"
" {min} and {max} are inclusive line numbers defining the range to delete
function s:RemoveRange(min, max) abort
	if b:root is s:null | return | endif
	let b:root = s:Splay(b:root, a:min)

	if b:root.right is s:null
		if b:root.key >= a:min && b:root.key <= a:max
			if b:root.left isnot s:null | let b:root.left.key += b:root.key | endif
			let b:root = b:root.left
		endif
	else
		" Do modified Hibbard deletion
		if b:root.key >= a:min && b:root.key <= a:max " Should remove root node but keep left subtree
			let rootkey = b:root.key
			let x = b:root.left
			let b:root = s:Splay(b:root.right, a:max - rootkey + 1)
			let b:root.left = x

			if x isnot s:null | let x.key -= b:root.key | endif
			let b:root.key += rootkey

			call s:Remove(a:max) " Root could still be less than max
		else " Should keep root node and left subtree
			let b:root.right = s:Splay(b:root.right, a:max - b:root.key + 1)
			if b:root.right.key < a:max
				let b:root.right.left = s:null
			else
				if b:root.right.right isnot s:null
					let b:root.right.right.key += b:root.right.key
				endif
				let b:root.right = b:root.right.right
			endif
		endif
	endif
endfunction

" Whether in the process of deleting whitespace.
"
" Ignore changes while that is the case.
let s:is_stripping = 0

function s:Listener(bufnr, start, end, added, changes) abort
	if s:is_stripping | return | endif

	" Remove existing in range
	if a:start < a:end
		call s:RemoveRange(a:start, a:end - 1)
	endif

	" Adjust line numbers
	let b:root = s:Splay(b:root, a:start)
	if b:root isnot s:null
		if b:root.key > a:start
			let b:root.key += a:added
			if b:root.left isnot s:null | let b:root.left.key -= a:added | endif
		elseif b:root.right isnot s:null
			let b:root.right.key += a:added
		endif
	endif

	" (Re-)Add lines in range with trailing whitespace
	for lnum in range(a:start, a:end - 1)
		let has_trailing_ws = getline(lnum) =~# '\s$'
		if has_trailing_ws
			call s:Put(lnum)
		endif
	endfor
endfunction

function s:OnBufEnter() abort
	if exists('b:root') | return | endif

	let b:root = s:null
	call listener_add(function('s:Listener'))
endfunction

" Recursively strips lines in the specified tree.
function s:StripTree(n, offset) abort
	silent execute (a:n.key + a:offset) 'StripTrailingWhitespace'

	if a:n.left isnot s:null | call s:StripTree(a:n.left, a:offset + a:n.key) | endif
	if a:n.right isnot s:null | call s:StripTree(a:n.right, a:offset + a:n.key) | endif
endfunction

function s:OnWrite() abort
	call listener_flush()

	let s:is_stripping = 1
	let save_cursor = getcurpos()
	try
		if b:root isnot s:null | call s:StripTree(b:root, 0) | endif
	finally
		call setpos('.', save_cursor)
		let s:is_stripping = 0
		let b:root = s:null
	endtry
endfunction

augroup strip_trailing_whitespace
	autocmd!
	autocmd BufEnter * call s:OnBufEnter()
	autocmd BufWritePre * call s:OnWrite()
augroup END
