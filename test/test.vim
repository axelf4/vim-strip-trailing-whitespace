function s:TestEdits(original, EditCb, expected) abort
	let fname = tempname()
	call writefile(a:original, fname)
	silent execute 'edit!' fname
	call a:EditCb()
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
