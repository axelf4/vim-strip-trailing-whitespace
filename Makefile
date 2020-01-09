VIM = vim

ifeq ($(VIM),vim)
	args = --not-a-term
else ifeq ($(VIM),nvim)
	args = --headless
endif

all: check

check:
	$(VIM) --clean $(args) -u runtest.vim

.PHONY: all check
