/*	$Tom: openbsd.c,v 1.1 2021/10/21 10:33:49 op Exp $	*/

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

#include <errno.h>
#include <lauxlib.h>
#include <lua.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int	openbsd_pledge(lua_State *);
static int	openbsd_unveil(lua_State *);

int
luaopen_openbsd(lua_State *L)
{
	lua_newtable(L);

	lua_pushcfunction(L, openbsd_pledge);
	lua_setfield(L, -2, "pledge");

	lua_pushcfunction(L, openbsd_unveil);
	lua_setfield(L, -2, "unveil");

	return 1;
}

#ifdef __OpenBSD__

static int
openbsd_pledge(lua_State *L)
{
	const char	*promises, *execpromises;

	promises = luaL_optstring(L, 1, NULL);
	execpromises = luaL_optstring(L, 2, NULL);

	if (pledge(promises, execpromises) == -1)
		luaL_error(L, "pledge(\"%s\", \"%s\"): %s",
		    promises, execpromises, strerror(errno));

	return 0;
}

static int
openbsd_unveil(lua_State *L)
{
	const char *path, *perm;

	path = luaL_checkstring(L, 1);
	perm = luaL_checkstring(L, 2);

	if (unveil(path, perm) == -1)
		luaL_error(L, "unveil(\"%s\", \"%s\"): %s",
		    path, perm, strerror(errno));

	return 0;
}

#else

static int
openbsd_pledge(lua_State *L)
{
	const char *promises, *execpromises;

	promises = luaL_optstring(L, 2, NULL);
	execpromises = luaL_optstring(L, 1, NULL);

	return 0;
}


static int
openbsd_unveil(lua_State *L)
{
	const char *path, *perm;

	path = luaL_checkstring(L, 2);
	perm = luaL_checkstring(L, 1);

	return 0;
}

#endif
