
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
#include <dirent.h>
#include <regex.h>

void yyerror(const char * s);
int yylex();

static int compare(const void* a, const void* b) {
  return strcmp(*(const char**)a, *(const char**)b);
}

void sort(char* arr[], int n){
  qsort(arr, n, sizeof(const char*), compare);
}

#define MAXFILENAME 1024

void expandWildcard(char* prefix, char* suffix) {
  if (suffix[0] == 0) {
    Command::_currentSimpleCommand->insertArgument(new std::string(prefix));
    return; 
  }

  char * s = strchr(suffix, '/');
  char component[MAXFILENAME];
  if (s != NULL) {
    strncpy(component, suffix, strlen(suffix) - strlen(s));
    component[strlen(s) - strlen(suffix)] = '\0';
    suffix = s + 1;
  } else {
    strcpy(component, suffix);
    component[strlen(suffix)] = '\0';
    suffix = suffix + strlen(suffix);
  }

  char newPrefix[MAXFILENAME];
  if (!strchr(component, '*') && !strchr(component, '?')) {
    if (prefix[0] == 0) sprintf(newPrefix, "%s", component);
    else sprintf(newPrefix, "%s/%s", prefix, component);
    expandWildcard(newPrefix, suffix);
    return;
  }

  // Generate the regular expression from the component
  char* reg = (char*) malloc( 2 * strlen(component)+10); 
  char* a = component;
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
  free(reg);

  if (res != 0) {
    perror("compile");
    return;
  }

  // End Regex Generation, Open Directory from Prefix
  char d[MAXFILENAME];

  if (prefix[0] == 0) {
    sprintf(d, "%s", ".");
  } else {
    sprintf(d, "./%s", prefix);
  }

  DIR * dir = opendir(d);

  if (dir == NULL) {
    perror("opendir");
    return; 
  }

  struct dirent * ent;
  int maxEntries = 20;
  int nEntries = 0;

  char ** array = (char**) malloc(maxEntries * sizeof(char*));
  while ( (ent = readdir(dir))!= NULL) {
    // Check if name matches
    regmatch_t match;
    if (regexec(&re, ent->d_name, 1, &match, 0) == 0) {
      if (ent->d_name[0] == '.') {
        if (component[0] == '.') {
          if (nEntries == maxEntries) {
            maxEntries *=2;
            array = (char**) realloc(array, maxEntries*sizeof(char*)); 
          }

          array[nEntries] = strdup(ent->d_name);
          nEntries++;             
        } 
      } else {
        if (nEntries == maxEntries) {
          maxEntries *=2;
          array = (char**) realloc(array, maxEntries*sizeof(char*)); 
        }

        array[nEntries] = strdup(ent->d_name);
        nEntries++;     
      } 
    }
  }

  regfree(&re);

  closedir(dir);

  sort(array, nEntries);

  // Add arguments 
  for (int i = 0; i < nEntries; i++) {
      if (prefix[0] == 0) sprintf(newPrefix, "%s", array[i]);
      else sprintf(newPrefix, "%s/%s", prefix, array[i]);
      expandWildcard(newPrefix, suffix);
      free(array[i]);
  }

  free(array);
}

void expandWildcardsIfNecessary(char* arg) {
  // Return if arg does not contain ‘*’ or ‘?’
  if (!strchr(arg, '*') && !strchr(arg, '?')) {
    Command::_currentSimpleCommand->insertArgument(new std::string(arg));
    return; 
  } else {
    char* prefix = (char*) malloc(sizeof(char));
    prefix[0] = '\0';
    expandWildcard(prefix, arg);
    free(prefix);
    return;
  }
/*
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
  free(reg);

  if (res != 0) {
    perror("compile");
    return;
  }

  DIR * dir = opendir(".");
  if (dir == NULL) {
    perror("opendir");
    return; 
  }

  struct dirent * ent;
  int maxEntries = 20;
  int nEntries = 0;

  char ** array = (char**) malloc(maxEntries*sizeof(char*));
  while ( (ent = readdir(dir))!= NULL) {
    // Check if name matches
    regmatch_t match;
    if (regexec(&re, ent->d_name, 1, &match, 0) == 0) {
      if (ent->d_name[0] == '.') {
        if (arg[0] == '.') {
          if (nEntries == maxEntries) {
            maxEntries *=2;
            array = (char**) realloc(array, maxEntries*sizeof(char*)); 
          }

          array[nEntries] = strdup(ent->d_name);
          nEntries++;             
        } 
      } else {
        if (nEntries == maxEntries) {
          maxEntries *=2;
          array = (char**) realloc(array, maxEntries*sizeof(char*)); 
        }

        array[nEntries] = strdup(ent->d_name);
        nEntries++;     
      } 
    }
  }

  regfree(&re);

  closedir(dir);

  sort(array, nEntries);

  // Add arguments 
  for (int i = 0; i < nEntries; i++) {
      Command::_currentSimpleCommand->insertArgument(new std::string(array[i])); 
      free(array[i]);
  }

  free(array);*/
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
    //expandWildcardsIfNecessary( (char*) ($1->c_str()) );
    expandWildcardsIfNecessary((char*) ($1->c_str()) );
    delete $1;
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
