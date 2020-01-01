function Test_OneLineUnchanged() abort
	let fname = tempname()
	let contents = ['line1 ']
	call writefile(contents, fname)
	silent execute 'edit' fname
	silent write
	call assert_equal(['line1 '], readfile(fname))
	%bwipeout!
endfunction

function Test_OneLineChanged() abort
	let fname = tempname()
	let contents = ['line1 ']
	call writefile(contents, fname)
	silent execute 'edit' fname
	normal! rf
	silent write
	call assert_equal(['fine1'], readfile(fname))
	%bwipeout!
endfunction
