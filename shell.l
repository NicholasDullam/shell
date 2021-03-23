
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <cstring>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include "y.tab.hh"
/*
#include <string.h>
#include "y.tab.h"

////////////  Start added code ///////////


extern “C” char * read_line();

int mygetc(FILE * f) {
  static char *p;
  char ch;

     if (!isatty(0)) {
  // stdin is not a tty. Call real getc
    return getc(f);
  }

  // stdin is a tty. Call our read_line.
  if (p==NULL || *p == 0) {
    char * s = read_line();
    p = s;
  }

  ch = *p;
  p++;

  return ch;
}

#undef getc
#define getc(f) mygetc(f)

/////////// End added code ///////////*/

#define MAX_INCLUDE_DEPTH 10
YY_BUFFER_STATE include_stack[MAX_INCLUDE_DEPTH];
int include_stack_ptr = 0;

static  void yyunput (int c,char *buf_ptr  );

char *getenv(const char *name);

void myunputc(int c) {
  unput(c);
}

void remove_character(char* s, char c, int p) {
  int j, n = strlen(s);
  int escaped = 0; 
  int count = 0;

  for (int i = j = 0; i < n; i++) {
    if (s[i] != c || escaped || (p && count == p)) {
      s[j++] = s[i];
      escaped = 0;
    } else {
      escaped = 1;
      count++;
    }
  }   

  s[j] = '\0';
}

/*void source(char *s) {
  FILE *yyin = fopen(s, "r");

  if (!yyin) {
    fprintf( stderr, "No File" );
  } else {
    yypush_buffer_state( yy_create_buffer( yyin, YY_BUF_SIZE ) );
    yyparse();
    fclose(yyin);
  }
}*/

void removeStartAndEnd(char* s) {
  int j, n = strlen(s);

  s[0] = '\0';
  for (int i = 1; i < n; i++) {
    s[i - 1] = s[i];
  }   
  s[n - 2] = '\0';
}

%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

">" {
  return GREAT;
}

">>" {
  return GREATGREAT;
}

"<" {
  return LESS;
}

"|" {
  return PIPE;
}

"&" {
  return AMPERSAND;
}

"2>" {
  return TWOGREAT;
}

">&" {
  return GREATAMPERSAND;
}

">>&" {
  return GREATGREATAMPERSAND;
}

[^ \n\t]*\$\([^\t\n][^\t\n]*\)[^ \n\t]* { 
  remove_character(yytext, '$', NULL);
  remove_character(yytext, '(', NULL);
  remove_character(yytext, ')', NULL);

  int pin[2], pout[2];
  pipe(pin); pipe(pout);

  int ret = fork();
  if (ret == 0) {
      close(pin[1]);
      close(pout[0]);

      dup2(pin[0], 0);
      close(pin[0]);

      dup2(pout[1], 1);
      close(pout[1]);
      
      // Execute shell executable
      execvp("/proc/self/exe", NULL);
      perror("Error in Child Process");
      exit(1);
  } else if (ret < 0) {
      perror("Error Forking Child");
      exit(1);
  }

  close(pin[0]);
  close(pout[1]);

  write(pin[1], strcat(yytext, "\n"), strlen(yytext) + 1);
  write(pin[1], "exit\n", 6);
  close(pin[1]);
  
  int size = 1024;
  char* buffer = (char*) malloc(sizeof(char) * size);
  char* iterator = buffer;
  int n = read(pout[0], iterator++, 1);
  while (n > 0) {
    n = read(pout[0], iterator++, 1);
    if (strlen(buffer) == size) {
      size = size * 2;
      realloc(buffer, size);
    }
  }

  *iterator = '\0';
  close(pout[0]);

  for (int i = strlen(buffer) - 1; i >= 0; i--) {
    char c = ' ';
    if (buffer[i] == '\n') {
      myunputc(' ');
    } else {
      myunputc(buffer[i]);
    }
  }
}

[^ \"\n\t]*(\\[^ \t\n]*)(\\[^ \t\n]*)*[^ \"\n\t]* { 
  remove_character(yytext, '\\', NULL);
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}

[^ \n\t\$\{\}]*\$\{[^ \t\n\{\}][^ \t\n\{\}]*\}[^ \n\t\$\{\}]* {
  int length = (int) strchr(yytext, "}") - strchr(yytext, "{");
  printf("%d", length);

  remove_character(yytext, '$', 1);
  remove_character(yytext, '{', NULL);
  remove_character(yytext, '}', NULL);

  int size = 1024;
  char* buffer = (char*) malloc(sizeof(char) * size);

  if (!strcmp(yytext, "$")) {
    // Return PID of the Shell
    sprintf(buffer, "%d", getpid());
  } else if (!strcmp(yytext, "?")) {
    // Return exit code of last command
    buffer = getenv(yytext);
  } else if (!strcmp(yytext, "!")) {
    // Return PID of last background process
    buffer = getenv(yytext);
  } else if (!strcmp(yytext, "_")) {
    // Return the last argument of the last command
    buffer = getenv("LAST_ARG");
  } else if (!strcmp(yytext, "SHELL")) {
    // Return the path of the shell
    buffer = getenv(yytext);
  } else {
    // Return ENV variable expansion
    buffer = getenv(yytext);
  }

  if(buffer) {
    for (int i = strlen(buffer) - 1; i >= 0; i--) {
      myunputc(buffer[i]);
    }
  }
}

[^ \t\n]*\"[^\t\n][^\t\n]*\"[^ \t\n]* {
  removeStartAndEnd(yytext);
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}

[^ \t\n\&\|\>\<\$\{\}][^ \t\n\&\$\{\}|\>\<\$\{\}]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}
