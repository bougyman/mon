CC=gcc
CFLAGS=-O2 -Wall -g

OBJS = muxpect.o setup.o io.o

all: muxpect

muxpect.o : muxpect.h

setup.o : muxpect.h

io.o : muxpect.h

muxpect: $(OBJS)
	$(CC) -o $@ $(OBJS)

clean:
	rm -f *.o muxpect core
