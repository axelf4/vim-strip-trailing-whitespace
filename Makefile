VIM := vim
unexport VIM
VIMFLAGS := $(if $(filter nvim,$(VIM)),--headless,--not-a-term)

all: test

TESTS := $(wildcard test/test*.vim)

$(TESTS):
	$(VIM) --clean $(VIMFLAGS) -u runtest.vim "$@"

test: $(TESTS)

.PHONY: all test $(TESTS)
