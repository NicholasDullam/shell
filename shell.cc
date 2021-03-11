#include <cstdio>
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include "shell.hh"

int yyparse(void);

void Shell::prompt() {
  printf("myshell>");
  fflush(stdout);
}

extern "C" void disp( int sig ){
  printf("\n");
  Shell::prompt();
}

extern "C" void zombie( int sig ){
  int pid = waitpid(-1, NULL, 0);
  if (pid >= 0) {
    printf("%d exited\n", pid);
  }
}

int main() {
  if (isatty(0)) {
    Shell::prompt();
  }

  struct sigaction sa;
  sa.sa_handler = disp;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_RESTART;
  int error = sigaction(SIGINT, &sa, NULL);
  if(error){
      perror("sigaction");
      exit(2);
  }

  struct sigaction sa_zombie;
  sa_zombie.sa_handler = zombie;
  sigemptyset(&sa_zombie.sa_mask);
  sa.sa_flags = SA_RESTART;
  int error_zombie = sigaction(SIGCHLD, &sa_zombie, NULL);
  if(error_zombie){
      perror("sigaction");
      exit(2);
  }

  yyparse();
}

Command Shell::_currentCommand;
