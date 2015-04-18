/*
 * $Id: muxpect.h,v 1.1.1.1 2004/06/09 05:18:04 trockij Exp $
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

#ifndef _MUXPECT_H
#define _MUXPECT_H

struct chat_sess
{
    char		expect[BUFSIZ];
    char		send[BUFSIZ];
    struct chat_sess	*next;
};

typedef struct chat_sess chat_sess_t;

struct muxconn
{
    int			fd;
    char		hostname[80];
    struct sockaddr_in	saddr;
    unsigned short	port;
    time_t		timeout;
    char		buf[8192];
    int			buf_offset;
    chat_sess_t		*ch_sess;
    regex_t		re_preg;
    char		re_errbuf[100];
    int			status;
    char		summ[80];
    char		detail[8192];
    struct muxconn	*next;
};

typedef struct muxconn muxconn_t;

/* status values */

#define MUXCONN_FAILURE		0	/* chat failure */
#define MUXCONN_SUCCESS		1	/* chat success */
#define MUXCONN_TIMEOUT		2	/* chat timeout */
#define MUXCONN_INPROGRESS	3	/* in progress (not complete) */
#define MUXCONN_SETUP		4	/* setup state */

int match_buffer (regex_t *, char *, char *, char *, int);
struct chat_sess *read_expect (char *file);
void dump_chat_sess (chat_sess_t *);
void usage (void);
muxconn_t * setup_muxconn_struct (char **, int, chat_sess_t *,
	unsigned short port, char *, int);
int setup_connect (muxconn_t *, char *, int);
int io_loop (muxconn_t *, int, char *, int);

#endif /* _MUXPECT_H */
