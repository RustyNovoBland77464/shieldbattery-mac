#include <windows.h>
#include <stdio.h>
int main(void) {
    FILE *o = fopen("C:\\sbtools\\hwcheck.txt", "w");
    DWORD serial = 0; GetVolumeInformationW(L"C:\\", NULL, 0, &serial, NULL, NULL, NULL, 0);
    fprintf(o, "C: serial=%lu (0x%08lx)\n", serial, serial);
    HKEY k; WCHAR buf[64]; DWORD len = sizeof buf;
    if (!RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Cryptography", 0, KEY_READ | KEY_WOW64_64KEY, &k) &&
        !RegQueryValueExW(k, L"MachineGuid", NULL, NULL, (BYTE *)buf, &len))
        fprintf(o, "MachineGuid=%ls\n", buf);
    else fprintf(o, "MachineGuid=<missing>\n");
    fclose(o); return 0;
}
