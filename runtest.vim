let s:has_errors = 0

try
	let s:scriptdir = fnamemodify(resolve(expand('<sfile>:p')), ':h')
	execute 'source' s:scriptdir .. '/plugin/strip_trailing_whitespace.vim'

	let s:testfiles = glob(s:scriptdir .. '/test/*.vim', 1, 1)
	for s:testfile in s:testfiles
		execute 'source' s:testfile

		let s:tests = execute('function /^Test_')->split("\n")->map({_, v -> v->matchstr('function \zs\k\+\ze()')})
		for s:test_function in s:tests
			let v:errors = []
			try
				echo 'Test' s:test_function
				execute 'call' s:test_function '()'
			catch
				call add(v:errors, "Uncaught exception in test: " .. v:exception .. " at " .. v:throwpoint)
			finally
				if !empty(v:errors)
					echo s:testfile .. ':1:Error'
					for s:error in v:errors
						echo s:error
					endfor
					let s:has_errors = 1
				endif
			endtry
		endfor
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
