/*	$Tom: gitc.c,v 1.1 2021/10/21 10:33:49 op Exp $	*/

/*
 * Copyright (c) 2021 Omar Polo <op@omarpolo.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#define LUA_LIB

#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <string.h>

static int	gitc_parsetree(lua_State *);

int
luaopen_gitc(lua_State *L)
{
	lua_newtable(L);

	lua_pushcfunction(L, gitc_parsetree);
	lua_setfield(L, -2, "parsetree");

	return 1;
}

static int
gitc_parsetree(lua_State *L)
{
	const char	*buf, *t, *end, *fname;
	char		 sha[21], ppsha[41];
	size_t		 len;
	int		 i, j, mode;

	buf = luaL_checklstring(L, 1, &len);
	end = buf + len;

	lua_newtable(L);

	for (i = 1; buf < end; ++i) {
		lua_pushnumber(L, i);
		lua_newtable(L);

		/* read the type */
		mode = 0;
		while (*buf >= '0' && *buf <= '7' && buf < end)
			mode = mode * 8 + *buf++ - '0';

		if (buf == end)
			luaL_error(L, "EOF");

		/* then a space */
		if (*buf++ != ' ')
			luaL_error(L, "expecting a space after the mode");

		/* then NUL-terminated file name */
		t = buf;
		while (t < end && *t != '\0')
			t++;
		if (t == end)
			luaL_error(L, "EOF");
		fname = buf;
		buf = ++t;

		/* then 20 byte of sha1 */
		if (end - buf < 20)
			luaL_error(L, "EOF");
		memcpy(sha, buf, 20);
		sha[20] = '\0';
		buf += 20;

		/* pretty print it */
		for (j = 0; j < 20; ++j)
			snprintf(ppsha + j*2, 3, "%02x", (uint8_t)sha[j]);

		/* save it */
		lua_pushstring(L, "mode");
		lua_pushinteger(L, mode);
		lua_settable(L, -3);

		lua_pushstring(L, "path");
		lua_pushstring(L, fname);
		lua_settable(L, -3);

		lua_pushstring(L, "ref");
		lua_pushstring(L, ppsha);
		lua_settable(L, -3);

		/* save this table in the return value */
		lua_settable(L, -3);
	}

	return 1;
}
