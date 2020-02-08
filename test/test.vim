function s:TestEdits(original, EditCb, expected) abort
	let fname = tempname()
	call writefile(a:original, fname)
	silent execute 'edit!' fname
	silent call a:EditCb()
	silent write
	call assert_equal(a:expected, readfile(fname))
endfunction

function Test_OneLineUnchanged() abort
	function! s:EditCb() abort
	endfunction
	call s:TestEdits(['foo '], function('s:EditCb'), ['foo '])
endfunction

function Test_OneLineChanged() abort
	function! s:EditCb() abort
		normal! rf
	endfunction
	call s:TestEdits(['line1 '], function('s:EditCb'), ['fine1'])
endfunction

function Test_AddLineAboveChange() abort
	function! s:EditCb() abort
		normal! rzO
	endfunction
	call s:TestEdits(['foo '], function('s:EditCb'), ['', 'zoo'])
endfunction

function Test_AbleToDisable() abort
	function! s:EditCb() abort
		let b:strip_trailing_whitespace_enabled = 0
		normal! rf
	endfunction
	call s:TestEdits(['line '], function('s:EditCb'), ['fine '])

	" Should remember modification sites even if disabled
	function! s:EditCb() abort
		let b:strip_trailing_whitespace_enabled = 0
		normal! rf
		silent write
		let b:strip_trailing_whitespace_enabled = 1
	endfunction
	call s:TestEdits(['line '], function('s:EditCb'), ['fine'])
endfunction

function Test_DisabledForMarkdown() abort
	function! s:EditCb() abort
		set filetype=markdown
		normal! rf
	endfunction
	call s:TestEdits(['line '], function('s:EditCb'), ['fine '])
endfunction

function Test_HandleManyLinesWithTWS() abort
	function! s:EditCb() abort
		execute 'normal! 100o '
	endfunction
	call s:TestEdits(['line '], function('s:EditCb'), extend(['line'], repeat([''], 100)))
endfunction
