
#include <stdlib.h>
#include <stdio.h>
#include <termios.h>
#include <string.h>

/* 
 * Sets terminal into raw mode. 
 * This causes having the characters available
 * immediately instead of waiting for a newline. 
 * Also there is no automatic echo.
 */

struct termios old_tty_settings;

void tty_raw_mode(void)
{
	tcgetattr(0, &old_tty_settings);

	struct termios tty_attr;
     
	tcgetattr(0,&tty_attr);

	/* Set raw mode. */
	tty_attr.c_lflag &= (~(ICANON|ECHO));
	tty_attr.c_cc[VTIME] = 0;
	tty_attr.c_cc[VMIN] = 1;
     
	tcsetattr(0,TCSANOW,&tty_attr);
}

void tty_term_mode(void)
{
	tcsetattr(0, TCSANOW, &old_tty_settings);
}
