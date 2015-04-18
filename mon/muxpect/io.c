/*
 *  $Id: io.c,v 1.1.1.1 2004/06/09 05:18:04 trockij Exp $
 */

/*
 * Copyright (C) 1998 Jim Trocki
 *
 *    This program is free software; you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation; either version 2 of the License, or
 *    (at your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <regex.h>
#include <errno.h>
#include <sys/time.h>
#include <sys/types.h>

#include "muxpect.h"

int
setup_connect (muxconn_t *muxlist, char *muxerr, int muxerrsiz)
{
    muxconn_t *c;
    int s, fl;
    int err;
    struct protoent *pe;
    
    c = muxlist;
    err = 0;

    if ((pe = getprotobyname ("tcp")) == NULL)
    {
	snprintf (muxerr, muxerrsiz, "could not look up tcp proto");
	return 0;
    }

    while (c != NULL)
    {
	s = socket (AF_INET, SOCK_STREAM, pe->p_proto);

	if (s < 0)
	{
	    snprintf (muxerr, muxerrsiz, "could not create socket: %s",
		    sys_errlist[errno]);
	    return 0;
	}

	/*
	 * set nonblocking
	 */
	c->fd = s;
	if ( (fl = fcntl (s, F_GETFL, 0)) < 0)
	{
	    snprintf (muxerr, muxerrsiz, "could not get flags: %s",
		    sys_errlist[errno]);
	    return 0;
	}

	fl |= O_NONBLOCK;
	
	if ( (fl = fcntl (s, F_SETFL, fl)) < 0)
	{
	    snprintf (muxerr, muxerrsiz, "could not set flags: %s",
		    sys_errlist[errno]);
	    return 0;
	}
	
	/*
	 * connect
	 */
	c->saddr.sin_port = htons (c->port);
	
	if (connect (s, &c->saddr, sizeof (c->saddr)) == -1 && errno != EINPROGRESS)
	{
	    c->status = MUXCONN_FAILURE;
	    snprintf (c->detail, sizeof (c->detail),
		    "could not connect: %s", sys_errlist[errno]);
	    snprintf (c->summ, sizeof (c->summ),
		    "%s", c->hostname);

	}
	else
	{
	    c->status = MUXCONN_INPROGRESS;
	}

	c = c->next;
    }

    return 1;
}


/*
 * main IO loop
 */
int
io_loop (muxconn_t *muxlist, int timeout,
	char *err,
	int errsiz)
{
    fd_set r_fd, w_fd;
    struct timeval tval, t0, t1;
    muxconn_t *c;
    int d;

    FD_ZERO (&r_fd);
    FD_ZERO (&w_fd);
    
    d = 0;
    c = muxlist;
    while (c->next != NULL)
    {
	if (c->status != MUXCONN_INPROGRESS)
	{
	    c = c->next;
	    continue;
	}
	FD_SET (c->fd, &r_fd);
	FD_SET (c->fd, &w_fd);
	if (c->fd > d)
	    d = c->fd;
    }

    timerclear (&tval);
    timerclear (&t0);
    timerclear (&t1);

    if (gettimeofday (&t0, NULL) == -1)
    {
	snprintf (err, errsiz, "could not gettimeofday: %s",
		sys_errlist[errno]);
	return 0;
    }
    
    while (timerisset (&tval))
    {
#if 0
	select ();
#endif

	if (gettimeofday (&t1, NULL) < 0)
	{
	    snprintf (err, errsiz, "could not gettimeofday: %s",
		    sys_errlist[errno]);
	    return 0;
	}
    }
    
    c = muxlist;
    while (c->next != NULL)
    {
	if (c->status == MUXCONN_INPROGRESS)
	    c->status = MUXCONN_TIMEOUT;
	c = c->next;
    }

    return 1;
}
