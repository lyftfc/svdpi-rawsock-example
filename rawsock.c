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
#define DBGP(...) {fprintf(_log, __VA_ARGS__); fprintf(_log, "\n");}

static svBit _isPromisc = sv_0;
static int _sockfd, _ifIdx, _ifMTU;
static uint8_t _ifMAC[ETH_ALEN];
static char _ifName[IFNAMSIZ];
static uint8_t *txBuff, *rxBuff;
static int txSize, rxProg, rxSize;

svBit dpiInitRawSocket(const char *ifname, svBit isProm);
svBit dpiDeinitRawSocket();
int dpiRecvFrame();
svBit dpiSendFrame();
uint8_t dpiGetByte();
void dpiPutByte(uint8_t val);

DPI_DLLESPEC
svBit dpiInitRawSocket(const char *ifname, svBit isProm)
{
    _log = fopen("rawsock_runtime.log", "w");

	if (strlen(ifname) >= IFNAMSIZ) return sv_0;
	else strncpy(_ifName, ifname, IFNAMSIZ);
    DBGP("ifname");

	_sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
	if (_sockfd < 0) return sv_0;
    DBGP("sockfd");

	struct ifreq req;

	/* Get interface index */
	memset(&req, 0, sizeof(req));
	strncpy(req.ifr_name, _ifName, IFNAMSIZ);
	if (ioctl(_sockfd, SIOCGIFINDEX, &req) < 0) return sv_0;
	_ifIdx = req.ifr_ifindex;
    DBGP("ifid");

	/* Get interface MAC address */
    memset(&req, 0, sizeof(req));
	strncpy(req.ifr_name, _ifName, IFNAMSIZ);
    if (ioctl(_sockfd, SIOCGIFHWADDR, &req) < 0) return sv_0;
    for (int i = 0; i < 6; i++)
        _ifMAC[i] = req.ifr_hwaddr.sa_data[i];
    DBGP("ifmac");
	
	/* Get interface L3 MTU */
    memset(&req, 0, sizeof(req));
    strncpy(req.ifr_name, _ifName, IFNAMSIZ);
    if (ioctl(_sockfd, SIOCGIFMTU, &req) < 0) return sv_0;
    _ifMTU = req.ifr_mtu;
    if (_ifMTU <= 0) return sv_0;
    txBuff = malloc(_ifMTU + 18);
    rxBuff = malloc(_ifMTU + 18);
    txSize = rxProg = rxSize = 0;
    DBGP("ifmtu");

	/* Set interface to promiscuous mode if requested*/
    if (isProm == sv_1) {
        memset(&req, 0, sizeof(req));
        strncpy(req.ifr_name, _ifName, IFNAMSIZ);
        if (ioctl(_sockfd, SIOCGIFFLAGS, &req) < 0) return sv_0;   // Get iface flags
        req.ifr_flags |= IFF_PROMISC;       // Set promiscuous
        if (ioctl(_sockfd, SIOCSIFFLAGS, &req) < 0) return sv_0;   // Write it back
        _isPromisc = sv_1;
        DBGP("promisc");
    }

	/* Socket binding */
    struct sockaddr_ll sa;
    sa.sll_family = AF_PACKET;
    sa.sll_protocol = htons(ETH_P_ALL);
    sa.sll_ifindex = _ifIdx;
    sa.sll_halen = ETH_ALEN;
    for (int i = 0; i < 6; i++)
        sa.sll_addr[i] = _ifMAC[i];
    if (bind(_sockfd, (struct sockaddr *)&sa, sizeof(sa)) < 0) return sv_0;
    DBGP("binding");

	return sv_1;
}

DPI_DLLESPEC
svBit dpiDeinitRawSocket()
{
    /* Unset interface from promiscuous mode if set */
    if (_isPromisc) {
        struct ifreq req;
        memset(&req, 0, sizeof(req));
        strncpy(req.ifr_name, _ifName, IFNAMSIZ);
        if (ioctl(_sockfd, SIOCGIFFLAGS, &req) < 0)  // Get iface flags
            return sv_0;
        req.ifr_flags &= ~IFF_PROMISC;      // Unset promiscuous
        if (ioctl(_sockfd, SIOCSIFFLAGS, &req) < 0)   // Write it back
            return sv_0;
    }

    if (_sockfd >= 0) close(_sockfd);
    DBGP("deinit");
    if (_log > 0) fclose(_log);

    return sv_1;
}

DPI_DLLESPEC
int dpiRecvFrame()
{
    rxSize = recvfrom(_sockfd, rxBuff, _ifMTU + 18, 0, NULL, NULL);
    if (rxSize <= 0) return 0;
    rxProg = 0;
    DBGP("recvframe");
    return rxSize;
}

DPI_DLLESPEC
svBit dpiSendFrame()
{
    struct sockaddr_ll sadr_ll;
    sadr_ll.sll_family = AF_PACKET;
    sadr_ll.sll_ifindex = _ifIdx; // index of interface
    sadr_ll.sll_halen = ETH_ALEN; // length of mac address
    for (int i = 0; i < ETH_ALEN; i++)
        sadr_ll.sll_addr[i] = txBuff[i];   // get mac address from frame
    
    ssize_t sentSize;
    sentSize = sendto(_sockfd, txBuff, txSize, 0, (struct sockaddr *)&sadr_ll, sizeof(sadr_ll));
    if (sentSize < txSize) return sv_0;
    txSize = 0;
    DBGP("sentframe");
    return sv_1;
}

DPI_DLLESPEC
uint8_t dpiGetByte()
{
    if (rxProg >= rxSize) return 0;
    uint8_t r = *(rxBuff + rxProg);
    rxProg++;
    return r;
}

DPI_DLLESPEC
void dpiPutByte(uint8_t val)
{
    if (txSize >= _ifMTU + 18) return;
    txBuff[txSize] = val;
    txSize++;
}
