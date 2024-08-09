#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include "threading.h"

#define DEBUG_LOG(msg,...) printf("threading DEBUG: " msg "\n" , ##__VA_ARGS__)
#define ERROR_LOG(msg,...) printf("threading ERROR: " msg "\n" , ##__VA_ARGS__)


/*
 * Reminder: sudo apt install glibc-doc --> Needed for man pages of pthread-mutex-lock, etc.
 * See https://askubuntu.com/questions/167521/where-is-the-man-page-for-pthread-mutex-lock
 *
 * Bonus: Install "Manpages" extension in VS Code (Extension ID meronz.manpages)
*/


/**
* Function passed to pthread_create() to tell thread what to do:
* wait, obtain mutex, wait, release mutex as described by thread_data structure
*/
void* threadfunc(void* thread_param) {

    int rc;

    // hint: use a cast like the one below to obtain thread arguments from your parameter
    struct thread_data* t_data = (struct thread_data *) thread_param;
    pthread_t thread_id = pthread_self();
    DEBUG_LOG("Ping from inside threadfunc() of thread %lu", (unsigned long int) thread_id);

    DEBUG_LOG(
            "Waiting for %d ms to obtain mutex in thread %lu",
            t_data->wait_to_obtain_ms, (unsigned long int) thread_id
    );
    rc = usleep(t_data->wait_to_obtain_ms * 1000);
    if (rc != 0) {
        ERROR_LOG(
                "usleep(wait_to_obtain_ms) failed with error %d in thread %lu\n",
                rc, (unsigned long int) thread_id
        );
        t_data->thread_complete_success = false;
        return t_data;
    }

    // Wait for mutex to get unlocked before locking it ourselves
    //
    // Excerpt from pthread_mutex_lock manpage as a reminder:
    // "
    //   [...]
    //   A thread attempting to lock a mutex that is already locked by another thread
    //   is suspended until the owning thread unlocks the mutex first.
    //   [...]
    // "
    pthread_mutex_lock(t_data->mutex);

    // Critical operation on shared resource protected by mutex...
    DEBUG_LOG("WE'VE GOT THE POWER!");
    DEBUG_LOG(
            "Obtained the mutex in thread %lu!", (unsigned long int) thread_id
    );
    DEBUG_LOG(
            "Let's do some critical stuff on the shared resource protected by the mutex here... ;p"
    );

    DEBUG_LOG(
            "Waiting for %d ms to release mutex in thread %lu",
            t_data->wait_to_release_ms, (unsigned long int) thread_id
    );
    rc = usleep(t_data->wait_to_release_ms * 1000);
    if (rc != 0) {
        ERROR_LOG(
                "usleep(wait_to_release_ms) failed with error %d in thread %lu\n",
                rc, (unsigned long int) thread_id
        );
        t_data->thread_complete_success = false;
        return t_data;
    }

    t_data->thread_complete_success = true;
    pthread_mutex_unlock(t_data->mutex);
    return t_data;
}


/**
* Function that starts threads with passed waiting times:
* allocate memory for thread_data, setup mutex and wait arguments,
* pass thread_data to created thread using threadfunc() as entry point.
* return true if thread was started successful.
*
* See implementation details in threading.h file comment block
*/
bool start_thread_obtaining_mutex(
        pthread_t *thread,
        pthread_mutex_t *mutex,
        int wait_to_obtain_ms,
        int wait_to_release_ms
) {

    struct thread_data *t_data = malloc(sizeof(struct thread_data));
    if (t_data == NULL) {
        ERROR_LOG("Failed to allocate memory for thread_data for thread %p\n", thread);
        return false;
    }

    t_data->mutex = mutex;
    t_data->wait_to_obtain_ms = wait_to_obtain_ms;
    t_data->wait_to_release_ms = wait_to_release_ms;
    t_data->thread_complete_success = false;

    DEBUG_LOG("Thread data allocated as follows:");
    DEBUG_LOG("mutex: %p", t_data->mutex);
    DEBUG_LOG("wait_to_obtain_ms: %d", t_data->wait_to_obtain_ms);
    DEBUG_LOG("wait_to_release_ms: %d", t_data->wait_to_release_ms);
    DEBUG_LOG("thread_complete_success: %d", t_data->thread_complete_success);

    int rc = pthread_create(
            thread,
            NULL, // Use default attributes
            threadfunc,
            t_data
    );

    if (rc != 0) {
        ERROR_LOG(
                "pthread_create failed with error %d creating thread %lu\n",
                rc, (unsigned long int) *thread
        );
        free(t_data);
        return false;
    }

    DEBUG_LOG(
            "Started thread %p with id %lu\n",
            (void *) thread, (unsigned long int) *thread
    );
    return true;
}
