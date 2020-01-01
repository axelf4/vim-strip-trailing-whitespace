all: check

check:
	vim --clean --not-a-term -u runtest.vim

.PHONY: all check
