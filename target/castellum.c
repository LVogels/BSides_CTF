/*
 * castellum — camp roll-call helper (Castra Arduenna)
 *
 * Installed SUID-root so any legionary can confirm the watch rotation.
 *
 * VULN: this helper runs with root privileges but calls an external command
 *       by its RELATIVE name via system(), inheriting the caller's $PATH.
 *       A low-privileged user can prepend a writable directory to $PATH and
 *       plant a malicious `date` binary -> code execution as root.
 */
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>

int main(void) {
    /* Elevate real+effective ids so the hijacked command runs as full root. */
    setuid(0);
    setgid(0);

    puts("[castellum] vices vigiliae probantur...");

    /* VULN: relative command name + inherited PATH = PATH hijack privesc. */
    system("date +\"[castellum] recensio confirmata hora %H:%M:%S\"");

    return 0;
}
