
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
  for (int i = j = 0; i < n; i++)
      if (s[i] != c)
          s[j++] = s[i];

  s[j] = '\0';
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

[^ \"\n\t]*(\\[^ \t\n]*)(\\[^ \t\n]*)*[^ \"\n\t]* { 
  yylval.cpp_string = new std::string(yytext);
  printf("Escaping");
  remove_character(yytext, '\\');
  return WORD;
}

[^ \t\n][^ \t\n]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}
