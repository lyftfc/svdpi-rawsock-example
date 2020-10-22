#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <linux/if_packet.h>
#include <linux/if_ether.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#define __USE_MISC		// TODO: Fix IntelliSense. REMOVE THIS WHEN COMPILE.
#include <net/if.h>
#include <svdpi.h>

#include <stdio.h>  // For debug purpose
static FILE *_log = NULL;
#define DBGP(...) if (_log) {fprintf(_log, __VA_ARGS__); fprintf(_log, "\n");}
#define LOGFILE "rawsock_runtime.log"

typedef int rsHandler;
typedef struct rsContext {
    svBit _isPromisc;
    int _sockfd, _ifIdx, _ifMTU;
    uint8_t _ifMAC[ETH_ALEN];
    char _ifName[IFNAMSIZ];
    uint8_t *txBuff, *rxBuff;
    int txSize, rxProg, rxSize;
} rsContext_t;

static rsContext_t *rsc = NULL;
static rsHandler rshCurr, rshTotal;

svBit dpiInitRSContext(int numSocks);
void dpiDeinitRSContext();
rsHandler dpiInitRawSocket(const char *ifname, svBit isProm);
svBit dpiDeinitRawSocket(rsHandler rsh);
int dpiRecvFrame(rsHandler rsh, svBit isBlk);
svBit dpiSendFrame(rsHandler rsh);
uint8_t dpiGetByte(rsHandler rsh);
void dpiPutByte(rsHandler rsh, uint8_t val);

/* 
 * Initialises the given number of raw socket contexts in a session.
 * Attempts to open a log file and allocate memory for the contexts
 * of numSocks sockets. Returns bit 1 on success, bit 0 otherwise. 
 * This function should be called first before any other function 
 * in this library.
 */
DPI_DLLESPEC
svBit dpiInitRSContext(int numSocks)
{
    _log = fopen(LOGFILE, "w");
    if (numSocks <= 0) return sv_0;
    rsc = calloc(numSocks, sizeof(rsContext_t));
    if (rsc == NULL) return sv_0;
    rshCurr = 0;
    rshTotal = numSocks;
    return sv_1;
}

/*
 * Deinitialises the library, releases all sockets and their contexts.
 * The log file is also released. This function should be called after 
 * finishing using other functions in the library.
 */
DPI_DLLESPEC
void dpiDeinitRSContext()
{
    for (rsHandler i = 0; i < rshCurr; i++)
        dpiDeinitRawSocket(i);
    free(rsc);
    rsc = NULL;
    DBGP("context deinit");
    if (_log) fclose(_log);
}

/* 
 * Initialise a raw socket on network interface of ifname.
 * Returns int-typed rsHandler which may be used in latter operations, 
 * specifying the opened socket. If isProm is set to 1, the given interface
 * will be put into promiscuous mode. Returns -1 on failure.
 */
DPI_DLLESPEC
rsHandler dpiInitRawSocket(const char *ifname, svBit isProm)
{
    rsContext_t c;
    if (rshCurr >= rshTotal) {
        DBGP("no spare context");
        return -1;
    }
    DBGP("sock context no. %d", rshCurr);

	if (strlen(ifname) >= IFNAMSIZ) return -1;
	else strncpy(c._ifName, ifname, IFNAMSIZ);
    DBGP("ifname");

	c._sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
	if (c._sockfd < 0) return -1;
    DBGP("sockfd");

	struct ifreq req;

	/* Get interface index */
	memset(&req, 0, sizeof(req));
	strncpy(req.ifr_name, c._ifName, IFNAMSIZ);
	if (ioctl(c._sockfd, SIOCGIFINDEX, &req) < 0) return -1;
	c._ifIdx = req.ifr_ifindex;
    DBGP("ifid");

	/* Get interface MAC address */
    memset(&req, 0, sizeof(req));
	strncpy(req.ifr_name, c._ifName, IFNAMSIZ);
    if (ioctl(c._sockfd, SIOCGIFHWADDR, &req) < 0) return -1;
    for (int i = 0; i < 6; i++)
        c._ifMAC[i] = req.ifr_hwaddr.sa_data[i];
    DBGP("ifmac");
	
	/* Get interface L3 MTU */
    memset(&req, 0, sizeof(req));
    strncpy(req.ifr_name, c._ifName, IFNAMSIZ);
    if (ioctl(c._sockfd, SIOCGIFMTU, &req) < 0) return -1;
    c._ifMTU = req.ifr_mtu;
    if (c._ifMTU <= 0) return -1;
    c.txBuff = malloc(c._ifMTU + 18);
    c.rxBuff = malloc(c._ifMTU + 18);
    c.txSize = c.rxProg = c.rxSize = 0;
    DBGP("ifmtu");

	/* Set interface to promiscuous mode if requested */
    if (isProm == sv_1) {
        memset(&req, 0, sizeof(req));
        strncpy(req.ifr_name, c._ifName, IFNAMSIZ);
        if (ioctl(c._sockfd, SIOCGIFFLAGS, &req) < 0) return -1;   // Get iface flags
        req.ifr_flags |= IFF_PROMISC;       // Set promiscuous
        if (ioctl(c._sockfd, SIOCSIFFLAGS, &req) < 0) return -1;   // Write it back
        c._isPromisc = sv_1;
        DBGP("promisc");
    } else {
        c._isPromisc = sv_0;
    }

	/* Socket binding */
    struct sockaddr_ll sa;
    sa.sll_family = AF_PACKET;
    sa.sll_protocol = htons(ETH_P_ALL);
    sa.sll_ifindex = c._ifIdx;
    sa.sll_halen = ETH_ALEN;
    for (int i = 0; i < 6; i++)
        sa.sll_addr[i] = c._ifMAC[i];
    if (bind(c._sockfd, (struct sockaddr *)&sa, sizeof(sa)) < 0) return -1;
    DBGP("binding");

    rsc[rshCurr] = c;
    rshCurr++;
	return (rshCurr - 1);
}

/* 
 * Deinitialise the socket at the given handler rsh. 
 * Returns sv_1 if finished without errors. Note that its context 
 * cannot be reused even after deinitialising.
 */
DPI_DLLESPEC
svBit dpiDeinitRawSocket(rsHandler rsh)
{
    /* Make sure that the socket is initialsed */
    if (rsc[rsh]._ifName[0] == 0) return sv_0;

    /* Release frame buffers */
    free(rsc[rsh].rxBuff);
    free(rsc[rsh].txBuff);

    /* Unset interface from promiscuous mode if set */
    if (rsc[rsh]._isPromisc) {
        struct ifreq req;
        memset(&req, 0, sizeof(req));
        strncpy(req.ifr_name, rsc[rsh]._ifName, IFNAMSIZ);
        if (ioctl(rsc[rsh]._sockfd, SIOCGIFFLAGS, &req) < 0) return sv_0; // Get iface flags
        req.ifr_flags &= ~IFF_PROMISC;      // Unset promiscuous
        if (ioctl(rsc[rsh]._sockfd, SIOCSIFFLAGS, &req) < 0) return sv_0; // Write it back
    }

    if (rsc[rsh]._sockfd >= 0) close(rsc[rsh]._sockfd);
    memset(&(rsc[rsh]), 0, sizeof(rsContext_t));
    DBGP("deinit sock no. %d", rsh);
    return sv_1;
}

/* 
 * Receives an ethernet frame from the opened socket and buffer it.
 * The function returns the number of bytes of the received frame. 
 * Returns 0 if an error has occured, or if isBlk is set to 0 and there 
 * is no frame immediately available.
 */
DPI_DLLESPEC
int dpiRecvFrame(rsHandler rsh, svBit isBlk)
{
    if (isBlk)
        rsc[rsh].rxSize = recvfrom(rsc[rsh]._sockfd, 
            rsc[rsh].rxBuff, rsc[rsh]._ifMTU + 18, 0, NULL, NULL);
    else
        rsc[rsh].rxSize = recvfrom(rsc[rsh]._sockfd, 
            rsc[rsh].rxBuff, rsc[rsh]._ifMTU + 18, MSG_DONTWAIT, NULL, NULL);
    if (rsc[rsh].rxSize <= 0) return 0;
    rsc[rsh].rxProg = 0;
    DBGP("recvframe sock %d", rsh);
    return rsc[rsh].rxSize;
}

/* 
 * Sends an ethernet frame from the buffer previously written to.
 * The function returns bit 1 if successfully finished, or 0 if failed.
 */
DPI_DLLESPEC
svBit dpiSendFrame(rsHandler rsh)
{
    struct sockaddr_ll sadr_ll;
    sadr_ll.sll_family = AF_PACKET;
    sadr_ll.sll_ifindex = rsc[rsh]._ifIdx; // index of interface
    sadr_ll.sll_halen = ETH_ALEN; // length of mac address
    for (int i = 0; i < ETH_ALEN; i++)
        sadr_ll.sll_addr[i] = rsc[rsh].txBuff[i];   // get mac address from frame
    
    ssize_t sentSize;
    sentSize = sendto(rsc[rsh]._sockfd, rsc[rsh].txBuff, rsc[rsh].txSize, 
        0, (struct sockaddr *)&sadr_ll, sizeof(sadr_ll));
    if (sentSize < rsc[rsh].txSize) return sv_0;
    rsc[rsh].txSize = 0;
    DBGP("sentframe sock %d", rsh);
    return sv_1;
}

/*
 * Returns the next byte from the Rx buffer after receiving a frame.
 * The caller is responsible for ensuring there are remaining bytes
 * in the buffer, or dpiRecvFrame() should be called in prior.
 */
DPI_DLLESPEC
uint8_t dpiGetByte(rsHandler rsh)
{
    if (rsc[rsh].rxProg >= rsc[rsh].rxSize) return 0;
    uint8_t r = *(rsc[rsh].rxBuff + rsc[rsh].rxProg);
    rsc[rsh].rxProg++;
    return r;
}

/*
 * Writes a byte to the Tx buffer for later sending.
 * The function simply discards the byte if the buffer is full.
 * dpiSendFrame() flushes the Tx buffer and send it to the socket.
 */
DPI_DLLESPEC
void dpiPutByte(rsHandler rsh, uint8_t val)
{
    if (rsc[rsh].txSize >= rsc[rsh]._ifMTU + 18) return;
    rsc[rsh].txBuff[rsc[rsh].txSize] = val;
    rsc[rsh].txSize++;
}
