#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

void *print_message_function( void *ptr );

int main()
{
     pthread_t thread1, thread2, thread3, thread4;
     const char *message1 = "Thread 1";
     const char *message2 = "Thread 2";
     const char *message3 = "Thread 3";
     const char *message4 = "Thread 4";
     int  iret1, iret2, iret3, iret4;

    /* Create independent threads each of which will execute function */

     iret1 = pthread_create( &thread1, NULL, print_message_function, (void*) message1);
     if(iret1)
     {
         fprintf(stderr,"Error - pthread_create() return code: %d\n",iret1);
         exit(EXIT_FAILURE);
     }

     iret2 = pthread_create( &thread2, NULL, print_message_function, (void*) message2);
     if(iret2)
     {
         fprintf(stderr,"Error - pthread_create() return code: %d\n",iret2);
         exit(EXIT_FAILURE);
     }

     iret3 = pthread_create( &thread3, NULL, print_message_function, (void*) message3);
     if(iret3)
     {
         fprintf(stderr,"Error - pthread_create() return code: %d\n",iret3);
         exit(EXIT_FAILURE);
     }

     iret4 = pthread_create( &thread4, NULL, print_message_function, (void*) message4);
     if(iret4)
     {
         fprintf(stderr,"Error - pthread_create() return code: %d\n",iret4);
         exit(EXIT_FAILURE);
     }

     printf("pthread_create() for thread 1 returns: %d\n",iret1);
     printf("pthread_create() for thread 2 returns: %d\n",iret2);

     /* Wait till threads are complete before main continues. Unless we  */
     /* wait we run the risk of executing an exit which will terminate   */
     /* the process and all threads before the threads have completed.   */

     pthread_join( thread1, NULL);
     pthread_join( thread2, NULL); 
     pthread_join( thread3, NULL);
     pthread_join( thread4, NULL); 

     exit(EXIT_SUCCESS);
}

void *print_message_function( void *ptr )
{
    while (1) {
        ;
    }
}
