let s:testfile = expand('%')
let s:has_errors = 0

try
	execute 'cd' fnamemodify(resolve(expand('<sfile>:p')), ':h')
	source plugin/strip_trailing_whitespace.vim

	source %
	" Query list of functions matching ^Test_
	let s:tests = map(split(execute('function /^Test_'), "\n"), 'matchstr(v:val, ''^function \zs\k\+\ze()'')')

	for s:test_function in s:tests
		let v:errors = []
		echo 'Test' s:test_function
		try
			execute 'call' s:test_function '()'
		catch
			call add(v:errors, "Uncaught exception in test: " .. v:exception .. " at " .. v:throwpoint)
		endtry
		if !empty(v:errors)
			echo s:testfile .. ':1:Error'
			for s:error in v:errors
				echo s:error
			endfor
			let s:has_errors = 1
		endif
	endfor
catch
	echo v:exception
	let s:has_errors = 1
endtry

if s:has_errors
	cquit! " Quit with an error code
else
	quit!
endif
