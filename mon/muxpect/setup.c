/*
 * $Id: setup.c,v 1.1.1.1 2004/06/09 05:18:04 trockij Exp $
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
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <regex.h>

#include "muxpect.h"


/*
 *   read expect/send  file
 */
struct chat_sess *
read_expect (char *file)
{
    FILE *f;
    char buf[BUFSIZ];
    chat_sess_t *first, *cur, *ncur;
    int send_expect;
    int lnum;
    
    if ((f = fopen (file, "r")) == NULL)
	return ((chat_sess_t *)NULL);
    
    send_expect = 1;
    first = cur = (chat_sess_t *) calloc (1, sizeof (chat_sess_t));
    if (first == NULL)
	return ((chat_sess_t *) NULL);
    first->next = (chat_sess_t *) NULL;
    cur->next = (chat_sess_t *) NULL;
    lnum = 0;

    while (fgets (buf, BUFSIZ, f) != NULL)
    {
	lnum++;
	if (strchr (buf, '#') == buf)
	    continue;
	
	buf[strlen (buf) -1] = '\0';
	if (send_expect)
	{
	    strncpy (cur->expect, buf, BUFSIZ);
	    send_expect--;
	}
	else
	{
	    strncpy (cur->send, buf, BUFSIZ);
	    send_expect++;

	    ncur = (chat_sess_t *) calloc (1, sizeof (chat_sess_t));
	    if (ncur == NULL)
	    {
		fclose (f);
		return ((chat_sess_t *) NULL);
	    }
	    ncur->next = (chat_sess_t *) NULL;
	    cur->next = ncur;
	    cur = ncur;
	}
    }
    
    cur->next = (chat_sess_t *) NULL;
    
    if (ferror (f))
    {
	fclose (f);
	return ((chat_sess_t *)NULL);
    }

    fclose (f);

    return (first);
}


/*
 *   debugging
 */
void
dump_chat_sess (chat_sess_t *c)
{
    chat_sess_t *p;
    
    p = c;
    while (p->next != NULL)
    {
	printf ("exp: %s\n", p->expect);
	printf ("snd: %s\n", p->send);
	p = p->next;
    }

    printf ("done\n");
}


/*
 *   help
 */
void
usage (void)
{
    printf ("usage:\n");
    printf ("  muxpect [-d] [-h] -f file\n");
    printf ("    -d          debug\n");
    printf ("    -h          show this help\n");
    printf ("    -f file     chat script filename\n");
    printf ("\n");
    exit (0);
}


/*
 *   create list of muxconns for all hosts
 */
muxconn_t *
setup_muxconn_struct (char **hosts,
	int ind,
	chat_sess_t *sess,
	unsigned short port,
	char *errbuf,
	int errbufsiz)
{
    muxconn_t *c, *l, *n;
    int i;
    struct hostent *hent;

    i = ind;
    l = (muxconn_t *)NULL;
    c = (muxconn_t *)NULL;

    while (hosts[i] != NULL)
    {
	n = calloc (1, sizeof (muxconn_t));
	if (n == NULL)
	{
	    strncpy (errbuf, "could not alloc memory", errbufsiz);
	    return ((muxconn_t *) NULL);
	}
	n->next = (muxconn_t *) NULL;

	if (c == (muxconn_t *) NULL)
	    c = n;
	else
	    l->next = n;

	n->fd = 0;
	strncpy (n->hostname, hosts[i], sizeof (n->hostname));
	n->timeout = 0;
	n->buf_offset = 0;
	n->ch_sess = sess;
	n->status = MUXCONN_INPROGRESS;
	n->next = (muxconn_t *) NULL;
	n->port = port;

	if (hosts[i][0] >= '0' && hosts[i][0] <= '9')
	{
	    if (inet_aton (hosts[i], &n->saddr.sin_addr) == 0)
	    {
		snprintf (errbuf, errbufsiz,
			"invalid IP address supplied, %s", hosts[i]);
		return ((muxconn_t *) NULL);
	    }
	}
	else
	{
	    if ((hent = gethostbyname (hosts[i])) == NULL)
	    {
		snprintf (errbuf, errbufsiz,
			"could not resolve host %s", hosts[i]);
		return ((muxconn_t *) NULL);
	    }
	    memcpy (&n->saddr.sin_addr, hent->h_addr_list[0], hent->h_length);
	}
	
	l = n;
	i++;
    }

    if (i == ind)
    {
	snprintf (errbuf, errbufsiz, "no hosts supplied");
	return ((muxconn_t *) NULL);
    }

    return (c);
}
