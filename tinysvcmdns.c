/*
 * tinysvcmdns - a tiny MDNS implementation for publishing services
 * Copyright (C) 2011 Darell Tan
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include <stdbool.h>
#include <signal.h>
#include <stdint.h>

#ifdef _WIN32
#include <winsock2.h>
#include <in6addr.h>
#include <ws2tcpip.h>
typedef uint32_t in_addr_t;
#define strcasecmp stricmp
#elif defined (linux) || defined (__FreeBSD__) || defined (sun)
#include <unistd.h>
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <strings.h>
#if defined (__FreeBSD__) || defined (sun)
#include <ifaddrs.h>
#include <net/if_dl.h>
#include <net/if_types.h>
#endif
#if defined (sun)
#include <sys/sockio.h>
#endif
#elif defined (__APPLE__)
#include <unistd.h>
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <ifaddrs.h>
#endif

#include "mdns.h"
#include "tinysvcmdns.h"

struct mdns_service *svc;
struct mdnsd *svr;

/*---------------------------------------------------------------------------*/
#ifdef WIN32
static void winsock_init(void) {
	WSADATA wsaData;
	WORD wVersionRequested = MAKEWORD(2, 2);
	int WSerr = WSAStartup(wVersionRequested, &wsaData);
	if (WSerr != 0) exit(1);
}


/*---------------------------------------------------------------------------*/
static void winsock_close(void) {
	WSACleanup();
}
#endif


/*---------------------------------------------------------------------------*/
#define MAX_INTERFACES 256
#define DEFAULT_INTERFACE 1
#if !defined(WIN32)
#define INVALID_SOCKET (-1)
#endif
static in_addr_t get_localhost(char **name)
{
#ifdef WIN32
	char buf[256];
	struct hostent *h = NULL;
	struct sockaddr_in LocalAddr;

	memset(&LocalAddr, 0, sizeof(LocalAddr));

	gethostname(buf, 256);
	h = gethostbyname(buf);

	if (name) *name = strdup(buf);

	if (h != NULL) {
		memcpy(&LocalAddr.sin_addr, h->h_addr_list[0], 4);
		return LocalAddr.sin_addr.s_addr;
	}
	else return INADDR_ANY;
#elif defined (__APPLE__) || defined(__FreeBSD__)
	struct ifaddrs *ifap, *ifa;

	if (name) {
		*name = malloc(256);
		gethostname(*name, 256);
	}

	if (getifaddrs(&ifap) != 0) return INADDR_ANY;

	/* cycle through available interfaces */
	for (ifa = ifap; ifa != NULL; ifa = ifa->ifa_next) {
		/* Skip loopback, point-to-point and down interfaces,
		 * except don't skip down interfaces
		 * if we're trying to get a list of configurable interfaces. */
		if ((ifa->ifa_flags & IFF_LOOPBACK) ||
			(!( ifa->ifa_flags & IFF_UP))) {
			continue;
		}
		if (ifa->ifa_addr->sa_family == AF_INET) {
			/* We don't want the loopback interface. */
			if (((struct sockaddr_in *)(ifa->ifa_addr))->sin_addr.s_addr ==
				htonl(INADDR_LOOPBACK)) {
				continue;
			}
			return ((struct sockaddr_in *)(ifa->ifa_addr))->sin_addr.s_addr;
			break;
		}
	}
	freeifaddrs(ifap);

	return INADDR_ANY;
#else
	char szBuffer[MAX_INTERFACES * sizeof (struct ifreq)];
	struct ifconf ifConf;
	struct ifreq ifReq;
	int nResult;
	long unsigned int i;
	int LocalSock;
	struct sockaddr_in LocalAddr;
	int j = 0;

	if (name) {
		*name = malloc(256);
		gethostname(*name, 256);
	}

	/* purify */
	memset(&ifConf,  0, sizeof(ifConf));
	memset(&ifReq,   0, sizeof(ifReq));
	memset(szBuffer, 0, sizeof(szBuffer));
	memset(&LocalAddr, 0, sizeof(LocalAddr));

	/* Create an unbound datagram socket to do the SIOCGIFADDR ioctl on.  */
	LocalSock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (LocalSock == INVALID_SOCKET) return false;
	/* Get the interface configuration information... */
	ifConf.ifc_len = (int)sizeof szBuffer;
	ifConf.ifc_ifcu.ifcu_buf = (caddr_t) szBuffer;
	nResult = ioctl(LocalSock, SIOCGIFCONF, &ifConf);
	if (nResult < 0) {
		close(LocalSock);
		return INADDR_ANY;
	}

	/* Cycle through the list of interfaces looking for IP addresses. */
	for (i = 0lu; i < (long unsigned int)ifConf.ifc_len && j < DEFAULT_INTERFACE; ) {
		struct ifreq *pifReq =
			(struct ifreq *)((caddr_t)ifConf.ifc_req + i);
		i += sizeof *pifReq;
		/* See if this is the sort of interface we want to deal with. */
		memset(ifReq.ifr_name, 0, sizeof(ifReq.ifr_name));
		strncpy(ifReq.ifr_name, pifReq->ifr_name,
			sizeof(ifReq.ifr_name) - 1);
		/* Skip loopback, point-to-point and down interfaces,
		 * except don't skip down interfaces
		 * if we're trying to get a list of configurable interfaces. */
		ioctl(LocalSock, SIOCGIFFLAGS, &ifReq);
		if ((ifReq.ifr_flags & IFF_LOOPBACK) ||
			(!(ifReq.ifr_flags & IFF_UP))) {
			continue;
		}
		if (pifReq->ifr_addr.sa_family == AF_INET) {
			/* Get a pointer to the address...*/
			memcpy(&LocalAddr, &pifReq->ifr_addr,
				sizeof pifReq->ifr_addr);
			/* We don't want the loopback interface. */
			if (LocalAddr.sin_addr.s_addr ==
				htonl(INADDR_LOOPBACK)) {
				continue;
			}
		}
		/* increment j if we found an address which is not loopback
		 * and is up */
		j++;
	}
	close(LocalSock);

	return LocalAddr.sin_addr.s_addr;
#endif
}



/*---------------------------------------------------------------------------*/
static int print_usage(void) {
	printf("[host <ip>] <identity> <type> <port> <txt> [txt] ... [txt]\n");
#ifdef WIN32
	winsock_close();
#endif
	return 1;
}



/*---------------------------------------------------------------------------*/
static void sighandler(int signum) {
	mdnsd_stop(svr);
#ifdef WIN32
	winsock_close();
#endif
	exit(0);
}


/*---------------------------------------------------------------------------*/
/*																			 */
/*---------------------------------------------------------------------------*/
#ifdef MDNS_SVC
int mdns_server(int argc, char *argv[]) {
#else
int main(int argc, char *argv[]) {
#endif
	char type[255];
	int port;
	const char **txt;
	struct in_addr host;
	char *hostname;
	int opt = 0;

	signal(SIGINT, sighandler);
	signal(SIGTERM, sighandler);
#if defined(SIGPIPE)
	signal(SIGPIPE, SIG_IGN);
#endif
#if defined(SIGQUIT)
	signal(SIGQUIT, sighandler);
#endif
#if defined(SIGHUP)
	signal(SIGHUP, sighandler);
#endif

#ifdef WIN32
	winsock_init();
#endif

	host.s_addr = get_localhost(&hostname);
	hostname = realloc(hostname, strlen(hostname) + strlen(".local") + 1);
	strcat(hostname, ".local");

	if (!strcasecmp(argv[1], "host")) {
		host.s_addr = inet_addr(argv[2]);
		opt = 2;
	}

	if (host.s_addr == INADDR_ANY) {
		printf("cannot find host address\n");
		free(hostname);
		return print_usage();

	}

	if (argc < 5+opt) return print_usage();

	port = atoi(argv[3+opt]);

	svr = mdnsd_start(host);
	if (svr == NULL) return print_usage();

	txt = malloc((argc - 4 + 1 - opt) * sizeof(char**));
	memcpy(txt, argv + 4 + opt, (argc - 4 - opt) * sizeof(char**));
	txt[argc - 4 - opt] = NULL;

	mdnsd_set_hostname(svr, hostname, host);

	sprintf(type, "%s.local", argv[2 + opt]);
	printf("host     : %s\nidentity : %s\ntype     : %s\n"
		   "ip       : %s\nport     : %u\n",
			hostname, argv[1 + opt], type, inet_ntoa(host), port);
	free(hostname);

	svc = mdnsd_register_svc(svr, argv[1 + opt], type, port, NULL, txt);
	// or, to remove service call: mdns_service_remove(svr, svc);
	mdns_service_destroy(svc);


#ifdef WIN32
	Sleep(INFINITE);
#else
	pause();
#endif

	mdnsd_stop(svr);

#ifdef WIN32
	winsock_close();
#endif

	return 0;
}

