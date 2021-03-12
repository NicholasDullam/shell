/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 * DO NOT PUT THIS PROJECT IN A PUBLIC REPOSITORY LIKE GIT. IF YOU WANT 
 * TO MAKE IT PUBLICALLY AVAILABLE YOU NEED TO REMOVE ANY SKELETON CODE 
 * AND REWRITE YOUR PROJECT SO IT IMPLEMENTS FUNCTIONALITY DIFFERENT THAN
 * WHAT IS SPECIFIED IN THE HANDOUT. WE OFTEN REUSE PART OF THE PROJECTS FROM  
 * SEMESTER TO SEMESTER AND PUTTING YOUR CODE IN A PUBLIC REPOSITORY
 * MAY FACILITATE ACADEMIC DISHONESTY.
 */

#include <stdlib.h>
#include <unistd.h>
#include <cstdio>
#include <cstdlib>

#include <iostream>

#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>

#include "command.hh"
#include "shell.hh"

Command::Command() {
    // Initialize a new vector of Simple Commands
    _simpleCommands = std::vector<SimpleCommand *>();

    _outFile = NULL;
    _inFile = NULL;
    _errFile = NULL;
    _background = false;
}

void Command::insertSimpleCommand( SimpleCommand * simpleCommand ) {
    // add the simple command to the vector
    _simpleCommands.push_back(simpleCommand);
}

void Command::clear() {
    // deallocate all the simple commands in the command vector
    for (auto simpleCommand : _simpleCommands) {
        delete simpleCommand;
    }

    // remove all references to the simple commands we've deallocated
    // (basically just sets the size to 0)
    _simpleCommands.clear();

    if ( _outFile && _errFile != _outFile ) {
        delete _outFile;
    }
    _outFile = NULL;

    if ( _inFile ) {
        delete _inFile;
    }
    _inFile = NULL;

    if ( _errFile) {
        delete _errFile;
    }
    _errFile = NULL;

    _background = false;
    _append = false;
}

void Command::print() {
    printf("\n\n");
    printf("              COMMAND TABLE                \n");
    printf("\n");
    printf("  #   Simple Commands\n");
    printf("  --- ----------------------------------------------------------\n");

    int i = 0;
    // iterate over the simple commands and print them nicely
    for ( auto & simpleCommand : _simpleCommands ) {
        printf("  %-3d ", i++ );
        simpleCommand->print();
    }

    printf( "\n\n" );
    printf( "  Output       Input        Error        Background\n" );
    printf( "  ------------ ------------ ------------ ------------\n" );
    printf( "  %-12s %-12s %-12s %-12s\n",
            _outFile?_outFile->c_str():"default",
            _inFile?_inFile->c_str():"default",
            _errFile?_errFile->c_str():"default",
            _background?"YES":"NO");
    printf( "\n\n" );
}

void Command::execute() {
    // Don't do anything if there are no simple commands
    if ( _simpleCommands.size() == 0 ) {
        if (isatty(0)) {
            Shell::prompt();
        }

        return;
    }

    // Print contents of Command data structure
    if (isatty(0)){
        print();
    }

    // Declare default file descriptors
    int tempin = dup ( 0 );
    int tempout = dup ( 1 );
    int temperr = dup ( 2 );

    int ret;
    int fdout;
    int fdin;
    int fderr;

    if (_inFile) {
        fdin = open((*_inFile).c_str(), O_RDONLY, 0666);
    } else {
        fdin = dup(tempin);
    }

    if (_errFile) {
        int flag = _append?O_APPEND:O_TRUNC;
        fderr = open((*_errFile).c_str(), flag | O_WRONLY | O_CREAT, 0666);
    } else {
        fderr = dup(temperr);
    }

    dup2(fderr, 2);
    close(fderr);

    for (int i = 0; i < _simpleCommands.size(); i++) {
        dup2(fdin, 0);
        close(fdin);

        // Declare environment variable reference
        extern char ** environ;

        // Dynamically allocated arguments from _simpleCommands[i]
        char** args = (char**) malloc((_simpleCommands[i]->_arguments.size() + 1) * sizeof(char*));
        for (int j = 0; j < _simpleCommands[i]->_arguments.size(); j++) {
            args[j] = (char*) (*_simpleCommands[i]->_arguments[j]).c_str();
        }

        // End arguments will null terminator
        args[_simpleCommands[i]->_arguments.size()] = NULL;

        // Built-in parent function parsing
        if (!strcmp(args[0], "setenv")) {
            int env = putenv(args[1]);
            printf("%d", env);
        } else if (!strcmp(args[0], "unsetenv")) {
            int env = unsetenv(args[1]);
        } else if (!strcmp(args[0], "cd")) {
            chdir(args[1]);
        } else if (!strcmp(args[0], "exit")) {
            exit(0);
        } else {
            if (i == _simpleCommands.size() - 1) {
                // Check file descriptors for last command
                if (_outFile) {
                    int flag = _append?O_APPEND:O_TRUNC;
                    fdout = open((*_outFile).c_str(), flag | O_WRONLY | O_CREAT, 0666);
                } else {
                    fdout = dup(tempout);
                }
            } else {
                // Pipe command if not the last command
                int fdpipe[2];
                pipe(fdpipe);
                fdin = fdpipe[0];
                fdout = fdpipe[1];
            }

            dup2(fdout, 1);
            close(fdout);

            // Initialize new child process
            ret = fork();

            if (ret == 0) {
                // Built-in function parsing and execution
                if (!strcmp(args[0], "printenv")){
                    char **p = environ;
                    while (*p != NULL){
                        printf("%s\n", *p);
                        p++;
                    }
                    exit(0);
                }

                // Execute arg[0] executable
                execvp(args[0], args);
                perror("Error in Child Process");
                exit(1);
            } 
            
            else if (ret < 0) {
                perror("Error Forking Child");
                return;
            }
        }

        // Free dynamically allocated arguments
        free(args);
    }

    // Restore default file descriptors
    dup2(tempin, 0);
    dup2(tempout, 1);
    dup2(temperr, 2);

    // Close default file descriptors
    close(tempin);
    close(tempout);
    close(temperr);

    // Wait for background processes
    if (!_background) {
        waitpid(ret, NULL, 0);
    }

    // Clear to prepare for next command
    clear();

    // Print new prompt
    if (isatty(0)) {
        Shell::prompt();
    }
}

SimpleCommand * Command::_currentSimpleCommand;
