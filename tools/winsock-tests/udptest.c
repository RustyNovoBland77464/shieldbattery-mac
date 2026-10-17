// Replays rally-point2 / noq-udp's socket setup step by step and reports which call fails.
#include <winsock2.h>
#include <ws2tcpip.h>
#include <mswsock.h>
#include <stdio.h>

static FILE *out;
#define STEP(name, expr) do { int _r = (expr); fprintf(out, "%-28s rc=%d err=%d\n", name, _r, _r ? WSAGetLastError() : 0); } while (0)

int main(void) {
    out = fopen("C:\\sbtools\\udptest.txt", "w");
    WSADATA w; WSAStartup(MAKEWORD(2, 2), &w);
    SOCKET s = WSASocketW(AF_INET6, SOCK_DGRAM, IPPROTO_UDP, NULL, 0, WSA_FLAG_OVERLAPPED | WSA_FLAG_NO_HANDLE_INHERIT);
    fprintf(out, "%-28s sock=%lld err=%d\n", "WSASocketW AF_INET6", (long long)s, s == INVALID_SOCKET ? WSAGetLastError() : 0);
    DWORD off = 0;
    STEP("setsockopt V6ONLY=0", setsockopt(s, IPPROTO_IPV6, IPV6_V6ONLY, (char *)&off, sizeof off));
    struct sockaddr_in6 a = {0}; a.sin6_family = AF_INET6; a.sin6_addr = in6addr_any;
    STEP("bind [::]:0", bind(s, (struct sockaddr *)&a, sizeof a));
    u_long nb = 1;
    STEP("ioctlsocket FIONBIO", ioctlsocket(s, FIONBIO, &nb));
    struct sockaddr_storage la; int ll = sizeof la;
    STEP("getsockname", getsockname(s, (struct sockaddr *)&la, &ll));
    fprintf(out, "  family=%d len=%d\n", la.ss_family, ll);
    DWORD v6 = 99; int vl = sizeof v6;
    STEP("getsockopt V6ONLY", getsockopt(s, IPPROTO_IPV6, IPV6_V6ONLY, (char *)&v6, &vl));
    fprintf(out, "  v6only=%lu len=%d\n", v6, vl);
    GUID g = WSAID_WSARECVMSG; void *fn = NULL; DWORD br;
    STEP("WSAIoctl WSARecvMsg ptr", WSAIoctl(s, SIO_GET_EXTENSION_FUNCTION_POINTER, &g, sizeof g, &fn, sizeof fn, &br, NULL, NULL));
    DWORD on = 1;
#ifndef IP_RECVECN
#define IP_RECVECN 50
#endif
#ifndef IPV6_RECVECN
#define IPV6_RECVECN 50
#endif
#ifndef IPV6_DONTFRAG
#define IPV6_DONTFRAG 14
#endif
    STEP("IP_DONTFRAGMENT", setsockopt(s, IPPROTO_IP, IP_DONTFRAGMENT, (char *)&on, sizeof on));
    STEP("IP_PKTINFO", setsockopt(s, IPPROTO_IP, IP_PKTINFO, (char *)&on, sizeof on));
    STEP("IP_RECVECN", setsockopt(s, IPPROTO_IP, IP_RECVECN, (char *)&on, sizeof on));
    STEP("IPV6_DONTFRAG", setsockopt(s, IPPROTO_IPV6, IPV6_DONTFRAG, (char *)&on, sizeof on));
    STEP("IPV6_PKTINFO", setsockopt(s, IPPROTO_IPV6, IPV6_PKTINFO, (char *)&on, sizeof on));
    STEP("IPV6_RECVECN", setsockopt(s, IPPROTO_IPV6, IPV6_RECVECN, (char *)&on, sizeof on));
    // Same thing with a v4 socket for comparison.
    SOCKET s4 = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    struct sockaddr_in a4 = {0}; a4.sin_family = AF_INET;
    STEP("v4 bind 0.0.0.0:0", bind(s4, (struct sockaddr *)&a4, sizeof a4));
    fclose(out);
    return 0;
}
