.PHONY: test test-stack

test-stack:
	cd tests && ./test-stack.sh

test-all:
	cd tests && ./run-all-tests.sh

test: test-all
