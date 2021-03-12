
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <cstring>
#include "y.tab.hh"

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

void remove_character(char* s, char c) {
  int j, n = strlen(s);
  int escaped = 0; 

  for (int i = j = 0; i < n; i++) {
    if (s[i] != c || escaped) {
      s[j++] = s[i];
      escaped = 0;
    } else {
      escaped = 1;
    }
  }   

  s[j] = '\0';
}

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
  remove_character(yytext, '$');
  remove_character(yytext, '(');
  remove_character(yytext, ')');

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

  char *buffer = (char*) malloc(sizeof(char) * 1024);
  char *iterator = buffer;
  write(pin[1], "exit\n", 6);
  close(pin[1]);

  while (read(pout[0], iterator, 1) != -1) {
    buffer[strlen(buffer) - 1] = '\0';
    printf("%s", buffer);
    iterator++;
  }

  close(pout[0]);

  yylval.cpp_string = new std::string(yytext);
  return WORD;
}

[^ \"\n\t]*(\\[^ \t\n]*)(\\[^ \t\n]*)*[^ \"\n\t]* { 
  remove_character(yytext, '\\');
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}

[^ \t\n]*\"[^\t\n][^\t\n]*\"[^ \t\n]* {
  removeStartAndEnd(yytext);
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}

[^ \t\n\&\|\>\<][^ \t\n\&\|\>\<]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}
