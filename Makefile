ARCH=		amd64
OS=		linux
LIBC=		musl

SRC_ENTRYPOINT=	src/shoebox.nim
SRC_FILES!=	find src/ -iname '*.nim' -type f


bin/shoebox_$(ARCH)_$(OS)_$(LIBC): $(SRC_FILES)
	mkdir -p bin/
	nimble c \
		--define:$(LIBC) \
		--define:release \
		--cpu:$(ARCH) \
		--opt:size \
		--out:$@ \
		$(SRC_ENTRYPOINT)


clean:
	find bin/ -type f -print -delete

.PHONY: clean
$(VERBOSE).SILENT:
