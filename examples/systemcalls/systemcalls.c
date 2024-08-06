#include "systemcalls.h"

/**
 * @param cmd the command to execute with system()
 * @return true if the command in @param cmd was executed
 *   successfully using the system() call, false if an error occurred,
 *   either in invocation of the system() call, or if a non-zero return
 *   value was returned by the command issued in @param cmd.
*/
bool do_system(const char *cmd) {
    printf("Running command: %s\n", cmd);
    int rc = system(cmd);
    printf("Return code: %d\n", rc);
    if (rc != 0) {
        return false;
    }

    printf("\n\n");
    return true;
}

/**
* @param count -The numbers of variables passed to the function. The variables are command to execute.
*   followed by arguments to pass to the command
*   Since exec() does not perform path expansion, the command to execute needs
*   to be an absolute path.
* @param ... - A list of 1 or more arguments after the @param count argument.
*   The first is always the full path to the command to execute with execv()
*   The remaining arguments are a list of arguments to pass to the command in execv()
* @return true if the command @param ... with arguments @param arguments were executed successfully
*   using the execv() call, false if an error occurred, either in invocation of the
*   fork, waitpid, or execv() command, or if a non-zero return value was returned
*   by the command issued in @param arguments with the specified arguments.
*/
bool do_exec(int count, ...) {
    printf("\n");
    va_list args;
    va_start(args, count);
    char *command[count+1];
    int i;
    for (i=0; i<count; i++) {
        command[i] = va_arg(args, char *);
    }
    // Last element has to be NULL, as expected by execv()
    command[count] = NULL;
    va_end(args);

    pid_t child_pid = fork();

    // Unable to fork child process
    if (child_pid == -1) {
        perror("child process");
        return false;

    // Child - execute command
    } else if (child_pid == 0) {
        printf("Child pid: %d\n", getpid());
        printf("Executing command: ");
        for (int i=0; i<count; i++) {
            printf("%s ", command[i]);
        }
        printf("\n");
        int cmd_status = execv(command[0], command);
        if (cmd_status == -1) {
            perror("execv");
            // Use _exit() to avoid issues with shared resources,
            // as suggested by GitHub Copilot
            _exit(1);
        }

    // Parent - wait for child process
    } else if (child_pid > 0) {
        printf("Parent pid: %d\n", getpid());
        int child_status = 1;
        waitpid(child_pid, &child_status, 0);
        printf("Child status: %d\n", child_status);
        if (child_status != 0) {
            printf("ERROR: Command in child process failed!\n");
            return false;
        }

    // Unexpected error
    } else {
        printf("Unpexted error!\n");
        return false;
    }

    printf("\n\n");
    return true;
}

/**
* @param outputfile - The full path to the file to write with command output.
*   This file will be closed at completion of the function call.
* All other parameters, see do_exec above
*/
bool do_exec_redirect(const char *outputfile, int count, ...) {
    printf("\n");
    if (outputfile == NULL) {
        printf("ERROR: Output file not specified!\n");
        return false;
    }

    va_list args;
    va_start(args, count);
    char *command[count+1];
    int i;
    for (i=0; i<count; i++) {
        command[i] = va_arg(args, char *);
    }
    // Last element has to be NULL, as expected by execv()
    command[count] = NULL;
    va_end(args);

/*
 * TODO
 *   Call execv, but first using https://stackoverflow.com/a/13784315/1446624 as a refernce,
 *   redirect standard out to a file specified by outputfile.
 *   The rest of the behaviour is same as do_exec()
 *
*/
    // Taken from https://stackoverflow.com/a/13784315/1446624 as requested in assignment
    int fd = open(outputfile, O_WRONLY|O_TRUNC|O_CREAT, 0644);
    if (fd < 0) { perror("open"); abort(); }

    int child_pid = fork();
    switch (child_pid) {
        // Unable to fork child process
        case -1:
            perror("child process"); abort();

        // Child - execute command
        case 0:
            // Redirect standard output (file descriptor 1) to file descriptor fd
            if (dup2(fd, 1) < 0) { perror("dup2"); abort(); }
            close(fd);
            // Reminder:
            // file descriptors that were open in the original process remain open in the new process
            // after calling execvp, so closing it here to save resources
            int cmd_status = execvp(command[0], command);
            if (cmd_status == -1) {
                perror("execvp");
                // Use _exit() to avoid issues with shared resources,
                // as suggested by GitHub Copilot
                _exit(1);
            }

        // Parent - wait for child process
        default:
            // Closing redundant file descriptor fd, as stdout is already redirected to outputfile
            // by child process
            close(fd);
            printf("Parent pid: %d\n", getpid());
            printf("\n");
            printf("Child pid: %d\n", getpid());
            printf("Executing command in child process: ");
            for (int i=0; i<count; i++) {
                printf("%s ", command[i]);
            }
            printf("\n");
            int child_status = 1;
            waitpid(child_pid, &child_status, 0);
            printf("Child status: %d\n", child_status);
            if (child_status != 0) {
                printf("ERROR: Command in child process failed!\n");
                return false;
            }
    }

    printf("\n\n");
    return true;
}
