#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>


int main(int argc, char *argv[]) {

    // Script config
    int nr_args_expected = 2;

    // Syslog config
    openlog(NULL, 0, LOG_USER);

    // Check number of CLI parameters
    if (argc-1 != nr_args_expected) {
        syslog(LOG_ERR, "Number of arguments passed is %d, but %d expected.\n", argc-1, nr_args_expected);
        syslog(LOG_ERR, "Usage: %s <writefile> <writestr>\n\n", argv[0]);
        syslog(LOG_ERR, "Example invocation:\n");
        syslog(LOG_ERR, "\t%s /tmp/aesd/assignment1/sample.txt ios\n\n", argv[0]);
        // See https://pubs.opengroup.org/onlinepubs/009695399/basedefs/errno.h.html
        errno = EINVAL;
        // Not returning EINVAL here, as full_test.sh expects 1 in this error case!
        return 1;
    }

    // Assign CLI parameter variables
    char *writefile = argv[1];
    char *writestr = argv[2];

    // Check if writestr is empty
    // by verifying if first character of string is null terminator ('\0')
    // as suggested by GitHub Copilot
    if (writestr[0] == '\0') {
        syslog(LOG_ERR, "ERROR: Provided search string is empty! Exiting!\n\n");
        errno = EINVAL;
        // Not returning EINVAL here, as full_test.sh expects 1 in this error case!
        return 1;
    }

    // Open writefile
    FILE *writefile_p = fopen(writefile, "w");
    if (writefile_p == NULL) {
        syslog(LOG_ERR, "Error opening file '%s': %s (%d)!\n", writefile, strerror(errno), errno);
        return errno;
    }

    // Write writestr to writefile
    syslog(LOG_DEBUG, "Writing %s to %s\n", writestr, writefile);
    // Use a format string to avoid compiler warning:
    // "warning: format not a string literal and no format arguments [-Wformat-security]"
    fprintf(writefile_p, "%s", writestr);

    // Close writefile
    fclose(writefile_p);

    // Exit successfully
    // See https://pubs.opengroup.org/onlinepubs/009695399/functions/exit.html
    return EXIT_SUCCESS;

}
