
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires 
{
#include <string>

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

// Token Requirements and Declarations
%token <cpp_string> WORD
%token NOTOKEN GREAT GREATGREAT GREATAMPERSAND GREATGREATAMPERSAND TWOGREAT NEWLINE PIPE AMPERSAND LESS

%{
//#define yylex yylex
#include <cstdio>
#include "shell.hh"
#include <string.h>

void yyerror(const char * s);
int yylex();

void expandWildcardsIfNecessary(char* arg) {
  // Return if arg does not contain ‘*’ or ‘?’
  if (!strchr(arg, '*') && !strchr(arg, '?')) {
    Command::_currentSimpleCommand->insertArgument(new std::string(arg));
    return; 
  }

  char* reg = (char*) malloc( 2 * strlen(arg)+10); 
  char* a = arg;
  char* r = reg;
  *r = '^'; r++;

  while (*a) {
    if (*a == '*') { *r='.'; r++; *r='*'; r++; }
    else if (*a == '?') { *r='.'; r++;}
    else if (*a == '.') { *r='\\'; r++; *r='.'; r++;} else { *r=*a; r++;}
    a++;
  }

  *r='$'; r++; *r=0;

  regex_t re;	
  int res = regcomp(&re, reg, REG_EXTENDED|REG_NOSUB);
  if (res != 0) {
    perror(“compile”);
    return;
  }

  DIR * dir = opendir(“.”);
  if (dir == NULL) {
    perror(“opendir”);
    return; 
  }

  struct dirent * ent;
  while ( (ent = readdir(dir))!= NULL) {
    // Check if name matches
    if (regexec(ent->d_name, expbuf ) ==0 ) {
      // Add argument 
      Command::_currentSimpleCommand->insertArgument(strdup(ent->d_name)); }
    }
    
    closedir(dir);
  }
}

%}

%%

goal:
  commands
  ;

commands:
  command
  | commands command
  ;

command: simple_command
       ;

simple_command:	
  pipe_list iomodifier_opt_list background_opt NEWLINE {
    //printf("   Yacc: Execute command\n");
    Shell::_currentCommand.execute();
  }
  | NEWLINE 
  | error NEWLINE { yyerrok; }
  ;

command_and_args:
  command_word argument_list {
    Shell::_currentCommand.
    insertSimpleCommand( Command::_currentSimpleCommand );
  }
  ;

argument_list:
  argument_list argument
  | /* can be empty */
  ;

argument:
  WORD {
    //printf("   Yacc: insert argument \"%s\"\n", $1->c_str());
    expandWildcardsIfNecessary( (char*) ($1->c_str()) );
  }
  ;

command_word:
  WORD {
    //printf("   Yacc: insert command \"%s\"\n", $1->c_str());
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
  }
  ;

iomodifier_opt:
  GREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (!Shell::_currentCommand._outFile) {
      Shell::_currentCommand._outFile = $2;
    } else {
      printf("Ambiguous output redirect.\n");
    }
  }
  | GREATGREAT WORD {
    //printf("   Yacc: append output \"%s\"\n", $2->c_str());
    if (!Shell::_currentCommand._outFile) {
      Shell::_currentCommand._outFile = $2;
      Shell::_currentCommand._append = true;
    } else {
      printf("Ambiguous output redirect.\n");
      exit(1);
    }
  }
  | GREATGREATAMPERSAND WORD {
    //printf("   Yacc: append both \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = $2;
    Shell::_currentCommand._append = true;
  }
  | GREATAMPERSAND WORD {
    //printf("   Yacc: insert both \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = $2;
  }
  | TWOGREAT WORD {
    //printf("   Yacc: insert error \"%s\"\n", $2->c_str());
    Shell::_currentCommand._errFile = $2;
  }
  | LESS WORD  {
    //printf("   Yacc: change inFile \"%s\"\n", $2->c_str());
    Shell::_currentCommand._inFile = $2;
  }
  ;

iomodifier_opt_list:
  iomodifier_opt_list iomodifier_opt
  | /* empty string */
  ;

pipe_list:
  pipe_list PIPE command_and_args
  | command_and_args
  ;

background_opt:
  AMPERSAND {
    Shell::_currentCommand._background = true;
  }
  | /* empty */
  ;

%%

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}

#if 0
main()
{
  yyparse();
}
#endif
