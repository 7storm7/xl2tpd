/*
 * Layer Two Tunnelling Protocol Daemon
 * PTY allocation routines (modern or legacy)
 * Copyright (C) 1998 Adtran, Inc.
 * Copyright (C) 2002 Jeff McAdams
 *
 * Mark Spencer
 *
 * This software is distributed under the terms
 * of the GPL, which you should have received
 * along with this source.
 */

#define _ISOC99_SOURCE
#define _XOPEN_SOURCE
#define _DEFAULT_SOURCE

#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include "l2tp.h"

#if defined(__OpenBSD__)
#include <util.h>
#else
#include <sys/types.h>
#include <sys/stat.h>
#endif

#ifdef USE_MODERN_PTY

#if defined(__OpenBSD__)
int getPtyMaster(char *ttybuf, int ttybuflen)
{
    int amaster, aslave;
    char tty[64];

    if (openpty(&amaster, &aslave, tty, NULL, NULL) == -1) {
        l2tp_log(LOG_WARNING, "%s: openpty() failed: %s\n", __FUNCTION__, strerror(errno));
        return -EINVAL;
    }

    strncpy(ttybuf, tty, ttybuflen);
    return amaster;
}
#else
int getPtyMaster(char *ttybuf, int ttybuflen)
{
    int fd;
    char *tty;

    fd = posix_openpt(O_RDWR | O_NOCTTY);
    if (fd < 0) {
        l2tp_log(LOG_WARNING, "%s: posix_openpt() failed: %s\n", __FUNCTION__, strerror(errno));
        return -EINVAL;
    }

    if (grantpt(fd) < 0 || unlockpt(fd) < 0) {
        l2tp_log(LOG_WARNING, "%s: grantpt/unlockpt failed: %s\n", __FUNCTION__, strerror(errno));
        close(fd);
        return -EINVAL;
    }

    tty = ptsname(fd);
    if (!tty) {
        l2tp_log(LOG_WARNING, "%s: ptsname() failed: %s\n", __FUNCTION__, strerror(errno));
        close(fd);
        return -EINVAL;
    }

    strncpy(ttybuf, tty, ttybuflen);
    return fd;
}
#endif // __OpenBSD__

#else // Legacy PTY fallback

#ifdef SOLARIS
#define PTY00 "/dev/ptyXX"
#define PTY10 "pqrstuvwxyz"
#define PTY01 "0123456789abcdef"
#endif

#ifdef LINUX
#define PTY00 "/dev/ptyXX"
#define PTY10 "pqrstuvwxyzabcde"
#define PTY01 "0123456789abcdef"
#endif

#if defined(FREEBSD) || defined(NETBSD)
#define PTY00 "/dev/ptyXX"
#define PTY10 "p"
#define PTY01 "0123456789abcdefghijklmnopqrstuv"
#endif

#ifndef OPENBSD
int getPtyMaster_pty(char *tty10, char *tty01)
{
    char *p10;
    char *p01;
    static char dev[] = PTY00;
    int fd;

    for (p10 = PTY10; *p10; p10++) {
        dev[8] = *p10;
        for (p01 = PTY01; *p01; p01++) {
            dev[9] = *p01;
            fd = open(dev, O_RDWR | O_NONBLOCK);
            if (fd >= 0) {
                *tty10 = *p10;
                *tty01 = *p01;
                return fd;
            }
        }
    }

    l2tp_log(LOG_CRIT, "%s: No more free pseudo-tty's\n", __FUNCTION__);
    return -1;
}

int getPtyMaster_ptmx(char *ttybuf, int ttybuflen)
{
    int fd;
    char *mx", O_RDWR);
    if (fd == -1) {
        l2tp_log(LOG_WARNING, "%s: unable to open /dev/ptmx\n", __FUNCTION__);
        return -EINVAL;
    }

    if (unlockpt(fd)) {
        l2tp_log(LOG_WARNING, "%s: unlockpt() failed\n", __FUNCTION__);
        close(fd);
        return -EINVAL;
    }

    tty = ptsname(fd);
    if (!tty) {
        l2tp_log(LOG_WARNING, "%s: ptsname() failed\n", __FUNCTION__);
        close(fd);
        return -EINVAL;
    }

    ttybuf[0] = '\0';
    strncat(ttybuf, tty, ttybuflen);
    return fd;
}
#endif

#ifdef OPENBSD
#include <util.h>
int getPtyMaster_ptm(char *ttybuf, int ttybuflen)
{
    int amaster, aslave;
    char tty[64];

    if (openpty(&amaster, &aslave, tty, NULL, NULL) == -1) {
        l2tp_log(LOG_WARNING, "%s: openpty() failed: %s\n", __FUNCTION__, strerror(errno));
        return -EINVAL;
    }

    strncpy(ttybuf, tty, ttybuflen);
    return amaster;
}
#endif

int getPtyMaster(char *ttybuf, int ttybuflen)
{
    int fd;
#ifndef OPENBSD
    fd = getPtyMaster_ptmx(ttybuf, ttybuflen);
    char a, b;

    if (fd >= 0) return fd;

    l2tp_log(LOG_WARNING, "%s: failed to use pts -- using legacy ptys\n", __FUNCTION__);
    fd = getPtyMaster_pty(&a, &b);

    if (fd >= 0) {
        snprintf(ttybuf, ttybuflen, "/dev/tty%c%c", a, b);
        return fd;
    }
#endif
#ifdef OPENBSD
    fd = getPtyMaster_ptm(ttybuf, ttybuflen);
    if (fd >= 0) return fd;
#endif
    return -EINVAL;
}
#endif // USE_MODERN_PTY
