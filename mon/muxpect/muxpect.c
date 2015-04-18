/*
 * $Id: muxpect.c,v 1.1.1.1 2004/06/09 05:18:04 trockij Exp $
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
#include <regex.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include "muxpect.h"

int debug;

/*
 * main
 */
int
main (int argc, char **argv)
{
    char fname[200], errbuf[100];
    chat_sess_t *sess;
    int c, help;
    unsigned short port;
    
    help = 0;
    debug = 0;
    memset (fname, 0, sizeof (fname));
    optind = 0;
    port = 0;

    while ((c = getopt (argc, argv, "dhf:p:")) != EOF)
    {
	switch (c) {
	    case 'h':
		help++;
		break;
	    case 'd':
		debug++;
		break;
	    case 'f':
		strncpy (fname, optarg, sizeof(fname));
		break;
	    case 'p':
		port = (unsigned short) strtol (optarg, (char **)NULL, 10);
		break;
	}
    }
    
    if (help)
	usage();
    
    if (fname[0] == '\0')
	usage();

    /*
     * read config file
     */
    sess = read_expect (fname);

    if (sess == NULL)
    {
	fprintf (stderr, "could not read\n");
	exit (1);
    }
    
    if (debug)
	dump_chat_sess (sess);

    if (setup_muxconn_struct (argv,
		optind,
		sess,
		port,
		errbuf,
		sizeof(errbuf)) == NULL)
    {
	printf ("could not setup sessions: %s\n", errbuf);
	exit (-1);
    }

    exit (0);
}


/*
 *   do a regex against a buffer, returning true or fals
 */
int
match_buffer (regex_t *preg,
	    char *pat,
	    char *buf,
	    char *errbuf,
	    int errbuflen)
{
    int r;

    r = regcomp (preg, pat, REG_EXTENDED | REG_ICASE | REG_NOSUB);

    if (r)
    {
	regerror (r, preg, errbuf, errbuflen);
	fprintf (stderr, "error in regcomp: %s\n", errbuf);
	exit (1);
    }
    
    r = regexec (preg, buf, 0, 0, 0);
    
    if (r == REG_NOMATCH)
    {
	fprintf (stderr, "no match\n");

    }
    else if (r != REG_NOERROR)
    {
	regerror (r, preg, errbuf, errbuflen);
	fprintf (stderr, "error in regexec: %s\n", errbuf);
	return (-1);
    }
    
    printf ("match\n");
    return (0);
}
