# $Tom: Makefile,v 1.1 2021/10/21 10:33:49 op Exp $

WARNS =		-Wall			\
		-Wextra			\
		-Wstrict-prototypes	\
		-Wwrite-strings		\
		-Wno-unused-parameter

# Change this to match how pkg-config identifies lua53 (or other
# versions) on your platform.  See the output of
#	pkg-config --list-all | grep lua
LUA =		lua53

CC =		cc
CFLAGS =	`pkg-config --cflags ${LUA} zlib` ${WARNS} -g -O0 -fPIC
LDFLAGS =	`pkg-config --libs   ${LUA} zlib`

.PHONY: all clean compile_flags.txt

all: fs.so gitc.so openbsd.so zlib.so

clean:
	rm -f *.o *.so

compile_flags.txt:
	printf "%s\n" ${CFLAGS} > compile_flags.txt

.SUFFIXES: .o .so
.o.so:
	${CC} $? -o $@ -shared ${LDFLAGS}
