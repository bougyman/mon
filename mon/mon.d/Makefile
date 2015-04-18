#
# $Id: Makefile,v 1.1.1.1 2004/06/09 05:18:05 trockij Exp $
#
# compiles on Linux, Solaris 2.5, Solaris 2.6, and AIX Version 4.2
#
CC = gcc
CFLAGS = -O2 -Wall -g
LDFLAGS =
LDLIBS =
# uncomment next line for Solaris
# LDLIBS = -lnsl -lsocket

MONPATH=/usr/lib/mon
DIALIN_MONITOR_REAL=$(MONPATH)/mon.d/dialin.monitor

PROGS = rpc.monitor dialin.monitor.wrap

all: $(PROGS)

rpc.monitor: rpc.monitor.c
	$(CC) -o rpc.monitor $(CFLAGS) $(LDFLAGS) rpc.monitor.c $(LDLIBS)

dialin.monitor.wrap: dialin.monitor.wrap.c
	$(CC) -o dialin.monitor.wrap $(CFLAGS) $(LDFLAGS) \
		-DREAL_DIALIN_MONITOR=\"$(DIALIN_MONITOR_REAL)\" \
		dialin.monitor.wrap.c

clean:
	rm -f $(PROGS)

install:
	install -d $(MONPATH)/mon.d
	install rpc.monitor $(MONPATH)/mon.d/
	install -g uucp -m 02555 dialin.monitor.wrap $(MONPATH)/mon.d/
