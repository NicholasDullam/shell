#include <cstdio>
#include <unistd.h>
#include <signal.h>
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

  yyparse();
}

Command Shell::_currentCommand;
