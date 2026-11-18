
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>

int main(void) {
    setuid(0);
    setgid(0);

    puts("[castellum] vices vigiliae probantur...");

    system("date +\"[castellum] recensio confirmata hora %H:%M:%S\"");

    return 0;
}
