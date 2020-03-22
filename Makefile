VIM = vim

ifeq ($(VIM),vim)
	args = --not-a-term
else ifeq ($(VIM),nvim)
	args = --headless
endif

all: check

check:
	$(foreach test,$(wildcard test/*.vim),$(VIM) --clean $(args) -u runtest.vim "$(test)")

.PHONY: all check
