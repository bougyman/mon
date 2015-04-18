/*
 * setgid wrapper for use with dialin.monitor. Required for
 * UUCP locking permissions in /var/lock.
 *
 * cc -o dialin.monitor.wrap dialin.monitor.wrap.c
 * chown root dialin.monitor.wrap
 * chgrp uucp  dialin.monitor.wrap
 * chmod 02555 dialin.monitor.wrap
 *
 * $Id: dialin.monitor.wrap.c,v 1.2 2004/11/15 14:45:18 vitroth Exp $
 *
*/

#include <unistd.h>

#ifndef REAL_DIALIN_MONITOR
#define REAL_DIALIN_MONITOR "/usr/lib/mon/mon.d/dialin.monitor"
#endif

int
main (int argc, char *argv[])
{
    char *real_img = REAL_DIALIN_MONITOR;

    argv[0] = real_img;

    /* exec */
    return execv (real_img, argv);
}
