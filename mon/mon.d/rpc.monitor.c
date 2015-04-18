/*
 * $Id: rpc.monitor.c,v 1.1.1.1 2004/06/09 05:18:04 trockij Exp $
 *
 * a monitor for RPC services, contains some code from rpcinfo(8)
 *
 * Copyright (C) 1986  Sun Microsystems, Inc.
 * Copyright (C) 1998  Daniel Quinlan
 *
 * Sun RPC is a product of Sun Microsystems, Inc. and is provided for
 * unrestricted use provided that this legend is included on all tape
 * media and as a part of the software program in whole or part.  Users
 * may copy or modify Sun RPC without charge, but are not authorized
 * to license or distribute it to anyone else except as part of a product or
 * program developed by the user.
 *
 * SUN RPC IS PROVIDED AS IS WITH NO WARRANTIES OF ANY KIND INCLUDING THE
 * WARRANTIES OF DESIGN, MERCHANTIBILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE, OR ARISING FROM A COURSE OF DEALING, USAGE OR TRADE PRACTICE.
 *
 * Sun RPC is provided with no support and without any obligation on the
 * part of Sun Microsystems, Inc. to assist in its use, correction,
 * modification or enhancement.
 *
 * SUN MICROSYSTEMS, INC. SHALL HAVE NO LIABILITY WITH RESPECT TO THE
 * INFRINGEMENT OF COPYRIGHTS, TRADE SECRETS OR ANY PATENTS BY SUN RPC
 * OR ANY PART THEREOF.
 *
 * In no event will Sun Microsystems, Inc. be liable for any lost revenue
 * or profits or other special, indirect and consequential damages, even if
 * Sun has been advised of the possibility of such damages.
 *
 * Sun Microsystems, Inc.
 * 2550 Garcia Avenue
 * Mountain View, California  94043
 */

#if (__svr4__ && __sun__)
#define SOLARIS
#endif

#include <ctype.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <unistd.h>
#include <rpc/rpc.h>
#include <rpc/pmap_prot.h>
#ifdef SOLARIS
#include <rpc/rpcent.h>
#include <rpc/clnt_soc.h>
#endif
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/time.h>
#include <arpa/inet.h>

#define DEFAULT_TIMEOUT 10

struct failure_ent {
    char *host;
    char *reason;
    struct failure_ent *next;
};

struct program_ent {
    int number;
    int required;
    int listed;
    struct program_ent *next;
};

/* function prototypes */
void test_host(char *host);
void test_programs (char *host, struct pmaplist *head);
void test_failure(char *host, char *reason);
void add_program(char *program, int required);
void print_failures();
int get_rpc_number(char *program);
#ifndef SOLARIS
int get_inet_address(struct sockaddr_in *, char *);
#endif
void usage();
void alarm_nop();

/* global variables */
int opt_all;			/* test all registered programs */
int opt_programs;		/* test specific programs */
int opt_verbose;		/* be verbose */
int timeout;			/* host timeout */
char *binary;			/* name of this program */
struct program_ent *programs;	/* list of programs to test */
struct failure_ent *failures;	/* list of test failures */

int main(int argc, char **argv) {
    int c;

    /* set defaults for global variables */
    opt_all = 0;
    opt_programs = 0;
    opt_verbose = 0;
    timeout = DEFAULT_TIMEOUT;
    programs = NULL;
    failures = NULL;
    binary = strdup(argv[0]);

    while ((c = getopt(argc, argv, "t:avhp:r:")) != EOF) {
	switch(c) {
	    case 't':
		timeout = atoi(optarg);
		break;
	    case 'a':
		opt_all = 1;
		break;
	    case 'p':
		opt_programs = 1;
		add_program(optarg, 0);
		break;
	    case 'r':
		opt_programs = 1;
		add_program(optarg, 1);
		break;
	    case 'v':
		opt_verbose = 1;
		break;
	    case 'h':
	    default:
		usage();
		break;
	}
    }

    while (optind < argc) {
	test_host(argv[optind++]);
    }
    if (failures) {
	print_failures();
	exit(1);
    }
    exit(0);
}

void add_program(char *program, int required) {
    struct program_ent *new, *tmp;

    new = (struct program_ent *) malloc(sizeof(struct program_ent));
    new->number = get_rpc_number(program);
    new->required = required;
    new->listed = 0;
    new->next = NULL;

    if (opt_verbose) {
	printf("adding test: %s, %d, %s\n", program, new->number,
	       required ? "required" : "unrequired");
    }

    if (programs == NULL) {
	programs = new;
    }
    else {
	tmp = programs;
	while (tmp->next != NULL) {
	    tmp = tmp->next;
	}
	tmp->next = new;
    }
}

int want_test(int number) {
    struct program_ent *tmp;

    tmp = programs;
    while (tmp != NULL) {
	if (number == tmp->number) {
	    return 1;
	}
	tmp = tmp->next;
    }
    return 0;
}

void test_failure(char *host, char *reason) {
    struct failure_ent *tmp, *new;

    /* chomp */
    if (reason[strlen(reason) - 1] == '\n') {
	reason[strlen(reason) - 1] = '\0';
    }

    new = (struct failure_ent *) malloc(sizeof(struct failure_ent));
    new->host = strdup(host);
    new->reason = strdup(reason);
    new->next = NULL;

    if (failures == NULL) {
	failures = new;
    }
    else {
	tmp = failures;
	while (tmp->next != NULL) {
	    tmp = tmp->next;
	}
	tmp->next = new;
    }
}

void print_failures() {
    struct failure_ent *tmp;
    char *last = NULL;

    /* print failed hosts, removing consecutive duplicates */
    tmp = failures;
    while (tmp != NULL) {
	if (!last || strcmp(last, tmp->host)) {
	    printf("%s%s", last ? " " : "", tmp->host);
	}
	last = tmp->host;
	tmp = tmp->next;
    }
    printf("\n");

    /* print reasons */
    tmp = failures;
    while (tmp != NULL) {
	printf("%s: %s\n", tmp->host, tmp->reason);
	tmp = tmp->next;
    }
}

void test_host(char *host) {
    struct pmaplist *head = NULL;
    struct timeval tv;
    CLIENT *client;
#ifndef SOLARIS
    struct sockaddr_in addr;
    int socket = RPC_ANYSOCK;
#endif

    tv.tv_sec = timeout;
    tv.tv_usec = 0;

#ifdef SOLARIS
    if ((client = clnt_create_timed(host, PMAPPROG,
				    PMAPVERS, "tcp", &tv)) == NULL) {
#else
    if (! get_inet_address(&addr, host)) {
	test_failure(host, "gethostbyname failed");
	return;
    }
    addr.sin_port = htons(PMAPPORT);
    signal(SIGALRM, alarm_nop);
    alarm(timeout);
    if ((client = clnttcp_create(&addr, PMAPPROG,
				 PMAPVERS, &socket, 0, 0)) == NULL) {
	alarm(0);
#endif
	test_failure(host, clnt_spcreateerror("clnttcp_create failed"));
	return;
    }
#ifndef SOLARIS
    alarm(0);
#endif
    clnt_control(client, CLSET_TIMEOUT, (char *) &tv);
    if (clnt_call(client, PMAPPROC_DUMP, (xdrproc_t) xdr_void, NULL,
		  (xdrproc_t) xdr_pmaplist, (char *) &head, tv) != RPC_SUCCESS)
    {
	test_failure(host, clnt_sperror(client, "clnt_call failed"));
	clnt_destroy(client);
	return;
    }
    if (head == NULL) {
	test_failure(host, "no remote programs registered");
	clnt_destroy(client);
	return;
    }
    if (opt_all || opt_programs) {
	test_programs(host, head);
    }
    clnt_destroy(client);
}

void test_programs (char *host, struct pmaplist *head) {
    struct timeval tv;
    CLIENT *tclient;
    struct protoent *proto;
    char failtext[80];
    int testing;
    struct rpcent *rpc;
    struct program_ent *ptmp;

    tv.tv_sec = timeout;
    tv.tv_usec = 0;

    if (opt_verbose)
	printf("testing      host   program vers proto   port\n");

    /* reset listed flag */
    for (ptmp = programs; ptmp != NULL; ptmp = ptmp->next)
	ptmp->listed = 0;

    for (; head != NULL; head = head->pml_next) {
	proto = getprotobynumber(head->pml_map.pm_prot);
	rpc = getrpcbynumber(head->pml_map.pm_prog);
	testing = (opt_all || want_test(head->pml_map.pm_prog));

	for (ptmp = programs; ptmp != NULL; ptmp = ptmp->next)
	    if (head->pml_map.pm_prog == ptmp->number)
		ptmp->listed = 1;

	if (opt_verbose) {
	    printf("%-7s", testing ? "true" : "false");
	    printf("%10s%10ld%5ld",
		   host, head->pml_map.pm_prog, head->pml_map.pm_vers);
	    if (proto)
		printf("%6s", proto->p_name);
	    else
		printf("%6ld", head->pml_map.pm_prot);
	    printf("%7ld", head->pml_map.pm_port);
	    if (rpc)
		printf("  %s\n", rpc->r_name);
	    else
		printf("\n");
	}

	if (!testing)
	    continue;

	if (!proto) {
	    fprintf(stderr, "%s: %ld: unknown protocol\n",
		    binary, head->pml_map.pm_prot);
	    exit(1);
	}

#ifdef SOLARIS
	if ((tclient = clnt_create_timed(host, head->pml_map.pm_prog,
					 head->pml_map.pm_vers, proto->p_name,
					 &tv))
	    == NULL) {
#else
	signal(SIGALRM, alarm_nop);
	alarm(timeout);
	if ((tclient = clnt_create(host, head->pml_map.pm_prog,
				   head->pml_map.pm_vers, proto->p_name))
	    == NULL) {
	    alarm(0);
#endif
	    if (rpc)
		snprintf(failtext, 80, "clnt_create failed: %s/%s/v%ld",
			 rpc->r_name, proto->p_name, (long)head->pml_map.pm_vers);
	    else
		snprintf(failtext, 80, "clnt_create failed: %ld/%s/v%ld",
			 head->pml_map.pm_prog, proto->p_name,
			 (long)head->pml_map.pm_vers);
	    test_failure(host, clnt_spcreateerror(failtext));
	    continue;
	}
	else {
#ifndef SOLARIS
	    alarm(0);
#endif
	    clnt_control(tclient, CLSET_TIMEOUT, (char *) &tv);

	    if (clnt_call(tclient, NULLPROC, (xdrproc_t) xdr_void, NULL,
			  (xdrproc_t) xdr_void, NULL, tv) != RPC_SUCCESS) {
		if (rpc)
		    snprintf(failtext, 80, "clnt_call failed: %s/%s/v%ld",
			     rpc->r_name, proto->p_name,
 			     (long)head->pml_map.pm_vers);
		else
		    snprintf(failtext, 80, "clnt_call failed: %ld/%s/v%ld",
			     head->pml_map.pm_prog, proto->p_name,
			     (long)head->pml_map.pm_vers);
		test_failure(host, clnt_sperror(tclient, failtext));
		clnt_destroy(tclient);
		continue;
	    }
	    clnt_destroy(tclient);
	}
    }

    /* did we find everything we want to require? */
    for (ptmp = programs; ptmp != NULL; ptmp = ptmp->next) {
	if (ptmp->required && ptmp->listed == 0) {
	    rpc = getrpcbynumber(ptmp->number);
	    if (rpc)
		snprintf(failtext, 80, "RPC program not registered: %s",
			 rpc->r_name);
	    else
		snprintf(failtext, 80, "RPC program not registered: %d",
			 ptmp->number);
	    test_failure(host, failtext);
	}
    }
}

int get_rpc_number(char *program) {
    struct rpcent *rpc;

    if (isalpha(*program)) {
	rpc = getrpcbyname(program);
	if (!rpc) {
	    fprintf(stderr, "%s: %s: unknown RPC program\n", binary, program);
	    exit(1);
	}
	return(rpc->r_number);
    }
    else {
	return(atoi(program));
    }
}

#ifndef SOLARIS
int get_inet_address(struct sockaddr_in *addr, char *host) {
    struct hostent *hp;

    bzero((char *) addr, sizeof *addr);
    addr->sin_addr.s_addr = (unsigned long) inet_addr(host);
    if (addr->sin_addr.s_addr == -1 || addr->sin_addr.s_addr == 0) {
	if ((hp = gethostbyname(host)) == NULL) {
	    return(0);
	}
	bcopy(hp->h_addr, (char *)&addr->sin_addr, hp->h_length);
    }
    addr->sin_family = AF_INET;
    return(1);
}
#endif

void usage () {
    printf(
 "Usage: %s [options] host [host...]\n"
 "   -t n          host timeout in seconds (%d seconds is the default)\n"
 "   -a            test all registered programs with RPC null procedure\n"
 "   -p program    test program (either a name or number) if registered with\n"
 "                    RPC null procedure, multiple -p flags may be specified\n"
 "   -r program    same as \"-p\", except fail if program is not registered\n"
 "   -v            verbose mode\n", binary, DEFAULT_TIMEOUT);
    exit(0);
}

void alarm_nop() {
    return;
}
