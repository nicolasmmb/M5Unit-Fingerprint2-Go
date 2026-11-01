TARGET ?= m5stick-c
TINYGO ?= tinygo

EXAMPLES := read enroll identify image templates match system notepad inf context concurrency

.PHONY: test examples

test:
	go test ./...

examples:
	@for e in $(EXAMPLES); do \
		echo "=== examples/$$e ==="; \
		$(TINYGO) build -target=$(TARGET) -size short -o /tmp/m5unit-fingerprint2-$$e.bin ./examples/$$e || exit 1; \
	done
