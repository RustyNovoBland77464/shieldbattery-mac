// Dual-stack IPv6 UDP socket -> IPv4-mapped destination round trip (DNS query to 1.1.1.1).
#include <winsock2.h>
#include <ws2tcpip.h>
#include <stdio.h>
int main(void) {
    FILE *out = fopen("C:\\sbtools\\dstest.txt", "w");
    WSADATA w; WSAStartup(MAKEWORD(2, 2), &w);
    SOCKET s = socket(AF_INET6, SOCK_DGRAM, IPPROTO_UDP);
    DWORD off = 0; setsockopt(s, IPPROTO_IPV6, IPV6_V6ONLY, (char *)&off, sizeof off);
    struct sockaddr_in6 a = {0}; a.sin6_family = AF_INET6; a.sin6_addr = in6addr_any;
    bind(s, (struct sockaddr *)&a, sizeof a);
    DWORD tmo = 3000; setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, (char *)&tmo, sizeof tmo);
    struct sockaddr_in6 d = {0}; d.sin6_family = AF_INET6; d.sin6_port = htons(53);
    inet_pton(AF_INET6, "::ffff:1.1.1.1", &d.sin6_addr);
    unsigned char q[] = {0x12,0x34,1,0,0,1,0,0,0,0,0,0, 7,'e','x','a','m','p','l','e',3,'c','o','m',0, 0,1,0,1};
    int sent = sendto(s, (char *)q, sizeof q, 0, (struct sockaddr *)&d, sizeof d);
    fprintf(out, "sendto=%d err=%d\n", sent, sent < 0 ? WSAGetLastError() : 0);
    char buf[512]; struct sockaddr_in6 from; int fl = sizeof from;
    int got = recvfrom(s, buf, sizeof buf, 0, (struct sockaddr *)&from, &fl);
    char ip[64] = "?"; if (got > 0) inet_ntop(AF_INET6, &from.sin6_addr, ip, sizeof ip);
    fprintf(out, "recvfrom=%d err=%d from=%s\n", got, got < 0 ? WSAGetLastError() : 0, ip);
    fclose(out); return 0;
}
