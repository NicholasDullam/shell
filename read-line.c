/*
 * CS252: Systems Programming
 * Purdue University
 * Example that shows how to read one line with simple editing
 * using raw terminal.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define MAX_BUFFER_LINE 2048
#define MAX_HISTORY 20

extern void tty_raw_mode(void);
extern void tty_term_mode(void);

void insertString(char* destination, int pos, char* seed) {
    char * strC;
    strC = (char*) malloc(strlen(destination)+strlen(seed)+1);
    strncpy(strC,destination,pos);
    strC[pos] = '\0';
    strcat(strC,seed);
    strcat(strC,destination+pos);
    strcpy(destination,strC);
    free(strC);
}

int line_length;
int cursor_position;

// Buffer where line is stored
char line_buffer[MAX_BUFFER_LINE];

// Simple history array
// This history does not change. 
// Yours have to be updated.
int history_index = 0;
int history_position = 0;
int history_length = 0;

char* history[MAX_HISTORY];

void read_line_print_usage()
{
  char * usage = "\n"
    " ctrl-?       Print usage\n"
    " Backspace    Deletes last character\n"
    " up arrow     See last command in the history\n";

  write(1, usage, strlen(usage));
}

/* 
 * Input a line with some basic editing.
 */
char * read_line() {

  // Set terminal in raw mode
  tty_raw_mode();

  line_length = 0;
  cursor_position = 0;

  // Read one line until enter is typed
  while (1) {

    // Read one character in raw mode.
    char ch;
    read(0, &ch, 1);

    if (ch>=32) {
      // It is a printable character. 
      // Do echo
      write(1,&ch,1);

      // If max number of character reached return.
      if (line_length==MAX_BUFFER_LINE-2) break; 

      // add char to buffer.
      int iterator = cursor_position;
      char prev = line_buffer[iterator];
      char val = prev;
      line_buffer[iterator]=ch;
      iterator++;

      while (prev != 0) {
        val = prev;
        prev = line_buffer[iterator];
        line_buffer[iterator] = val;
        iterator++;
      }

      line_length++;
      cursor_position++;

      if (line_length != cursor_position) {
        for (int i = cursor_position; i < line_length; i++) {
          ch = line_buffer[i];
          write(1,&ch,1);
        }

        for (int i = cursor_position; i < line_length; i++) {
          ch = 8;
          write(1,&ch,1);
        }
      }
    }
    else if (ch==10) {
      // <Enter> was typed. Return line
      
      // Print newline
      write(1,&ch,1);

      break;
    }
    else if (ch == 31) {
      // ctrl-?
      read_line_print_usage();
      line_buffer[0]=0;
      break;
    } else if (ch == 4) {
      if (cursor_position < line_length) {
        // Write a space to erase the last character read
        ch = ' ';
        write(1,&ch,1);

        // Go back one character
        ch = 8;
        write(1,&ch,1);


        // Remove previous index and move to the left
        int iterator = cursor_position;
        char next = line_buffer[iterator + 1];
        line_buffer[iterator] = next;
        iterator++;

        while (iterator < line_length) {
          next = line_buffer[iterator + 1];
          line_buffer[iterator] = next;
          iterator++;
        }

        if (line_length != cursor_position) {
          for (int i = cursor_position; i < line_length - 1; i++) {
            ch = line_buffer[i];
            write(1,&ch,1);
          }

          ch = ' ';
          write(1,&ch,1);

          for (int i = cursor_position; i < line_length; i++) {
            ch = 8;
            write(1,&ch,1);
          }
        }

        line_length--;
      }
    } else if (ch == 8) {
      if (cursor_position > 0) {
        // <backspace> was typed. Remove previous character read.

        // Go back one character
        ch = 8;
        write(1,&ch,1);

        // Write a space to erase the last character read
        ch = ' ';
        write(1,&ch,1);

        // Go back one character
        ch = 8;
        write(1,&ch,1);

        if (line_length != cursor_position) {
          for (int i = cursor_position; i < line_length; i++) {
            ch = line_buffer[i];
            write(1,&ch,1);
          }

          ch = ' ';
          write(1,&ch,1);

          for (int i = cursor_position; i < line_length + 1; i++) {
            ch = 8;
            write(1,&ch,1);
          }
        }

        // Remove index and move to the left
        int iterator = cursor_position - 1;
        char next = line_buffer[iterator + 1];
        line_buffer[iterator] = next;
        iterator++;

        while (iterator < line_length) {
          next = line_buffer[iterator + 1];
          line_buffer[iterator] = next;
          iterator++;
        }

        cursor_position--;
        line_length--;
      }
    } else if (ch==27) {
      // Escape sequence. Read two chars more
      //
      // HINT: Use the program "keyboard-example" to
      // see the ascii code for the different chars typed.
      //

      char ch1; 
      char ch2;
      read(0, &ch1, 1);
      read(0, &ch2, 1);

      if (ch1==91 && ch2==65) {
        // Up arrow. Print next line in history.
        if (history_length) {
          // Erase old line
          // Print backspaces
          int i = 0;
          for (i =0; i < line_length; i++) {
            ch = 8;
            write(1,&ch,1);
          }

          // Print spaces on top
          for (i =0; i < line_length; i++) {
            ch = ' ';
            write(1,&ch,1);
          }

          // Print backspaces
          for (i =0; i < line_length; i++) {
            ch = 8;
            write(1,&ch,1);
          }	

          // Copy line from history
          strcpy(line_buffer, history[history_position]);
          line_buffer[strlen(history[history_position])] = '\0';
          line_length = strlen(line_buffer);
          cursor_position = line_length;
          history_position= (history_position + 1) % history_length;

          // echo line
          write(1, line_buffer, line_length);
        } else {
          ch = '\a';
          printf("%c", ch);
        }
      } else if (ch1==91 && ch2==66) {
        // Down arrow. Print next line in history.
        if (history_length) {
          // Erase old line
          // Print backspaces
          int i = 0;
          for (i =0; i < line_length; i++) {
            ch = 8;
            write(1,&ch,1);
          }

          // Print spaces on top
          for (i =0; i < line_length; i++) {
            ch = ' ';
            write(1,&ch,1);
          }

          // Print backspaces
          for (i =0; i < line_length; i++) {
            ch = 8;
            write(1,&ch,1);
          }	

          // Copy line from history
          strcpy(line_buffer, history[history_position]);
          line_buffer[strlen(history[history_position])] = '\0';
          line_length = strlen(line_buffer);
          cursor_position = line_length;
          if (history_position == 0) history_position = history_length - 1;
          else history_position--;

          // echo line
          write(1, line_buffer, line_length);
        } else {
          ch = '\a';
          printf("%c", ch);
        }
      } else if (ch1==91 && ch2==68) {
        // Left Arrow
        if (cursor_position > 0) {
          ch = 8;
          write(1,&ch,1);
          cursor_position--;
        }
      } else if (ch1==91 && ch2==67) {
        // Right Arrow
        if (cursor_position < line_length) {
          ch = line_buffer[cursor_position++];
          write(1,&ch,1);
        }
      }
    } else if (ch == 5) {
      // CTRL E
      for (int i = cursor_position; i < line_length; i++) {
        ch = line_buffer[i];
        write(1,&ch,1);
      }

      cursor_position = line_length;
    } else if (ch == 1) {
      // CTRL A
      for (int i = 0; i < cursor_position; i++) {
        ch = 8;
        write(1,&ch,1);
      }

      cursor_position = 0;
    }
  } 

  // Add eol and null char at the end of string
  line_buffer[line_length]=10;
  line_length++;
  line_buffer[line_length]=0;


  // Generate history elements and reset history_position
  history[history_index % MAX_HISTORY] = (char*) malloc(sizeof(char) * strlen(line_buffer));
  strncpy(history[history_index % MAX_HISTORY], line_buffer, strlen(line_buffer) - 1);
  history[history_index % MAX_HISTORY][strlen(line_buffer) - 1] = '\0';
  if (history_length < MAX_HISTORY) history_length++;
  history_position = history_index % MAX_HISTORY;
  history_index++;

  tty_term_mode();

  return line_buffer;
}

