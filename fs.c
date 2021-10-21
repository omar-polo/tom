/*	$Tom: fs.c,v 1.1 2021/10/21 10:33:49 op Exp $	*/

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

#include <sys/types.h>

#include <dirent.h>
#include <errno.h>
#include <glob.h>
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <stdio.h>
#include <string.h>

static int	fs_ls(lua_State *);
static int	fs_ls_iter(lua_State *);

static int	fs_dirs(lua_State *);
static int	fs_dirs_iter(lua_State *);

static int	fs_dir__gc(lua_State *);

static int	fs_glob(lua_State *);

int
luaopen_fs(lua_State *L)
{
	luaL_newmetatable(L, "fs.dir");
	lua_pushstring(L, "__gc");
	lua_pushcfunction(L, fs_dir__gc);
	lua_settable(L, -3);

	lua_newtable(L);

	lua_pushcfunction(L, fs_ls);
	lua_setfield(L, -2, "ls");

	lua_pushcfunction(L, fs_dirs);
	lua_setfield(L, -2, "dirs");

	lua_pushcfunction(L, fs_glob);
	lua_setfield(L, -2, "glob");

	return 1;
}

static int
open_dir_iter(lua_State *L, const char *path, int (*iter)(lua_State *))
{
	DIR **d;

	d = lua_newuserdata(L, sizeof(DIR *));

	luaL_getmetatable(L, "fs.dir");
	lua_setmetatable(L, -2);

	if ((*d = opendir(path)) == NULL)
		luaL_error(L, "cannot open \"%s\": %s",
		    path, strerror(errno));

	lua_pushcclosure(L, iter, 1);
	return 1;
}

static int
fs_ls(lua_State *L)
{
	const char *path;

	path = luaL_checkstring(L, 1);
	return open_dir_iter(L, path, fs_ls_iter);
}

static int
fs_ls_iter(lua_State *L)
{
	DIR		*d;
	struct dirent	*entry;

	d = *(DIR **)lua_touserdata(L, lua_upvalueindex(1));

	if ((entry = readdir(d)) == NULL)
		return 0;

	lua_pushstring(L, entry->d_name);
	return 1;
}

static int
fs_dirs(lua_State *L)
{
	const char	 *path;

	path = luaL_checkstring(L, 1);
	return open_dir_iter(L, path, fs_dirs_iter);
}

static int
fs_dirs_iter(lua_State *L)
{
	DIR		*d;
	struct dirent	*entry;

	d = *(DIR **)lua_touserdata(L, lua_upvalueindex(1));

	do {
		if ((entry = readdir(d)) == NULL)
			return 0;
	} while (entry->d_type != DT_DIR);

	lua_pushstring(L, entry->d_name);
	return 1;
}

static int
fs_dir__gc(lua_State *L)
{
	DIR *d;

	d = *(DIR **)lua_touserdata(L, 1);
	if (d != NULL)
		closedir(d);
	return 0;
}

static int
fs_glob(lua_State *L)
{
	int	flags;
	size_t	i, n;
	glob_t	g;

	lua_newtable(L);

	/* 1 because we've just pushed a table */
	if ((n = lua_gettop(L)) == 1)
                return 1;

	/*
	 * Traverse all the arguments to ensure that they're all
	 * strings.  luaL_check* uses longjmp on error, so we can't
	 * blindly use it during the glob loop below.  Also, argument
	 * with depth `n' is the table we've just pushed.
	 */
	for (i = 1; i < n; ++i)
		luaL_checkstring(L, i);

	for (i = 1; i < n; ++i) {
		flags = GLOB_MARK | GLOB_NOESCAPE;
		if (i != 1)
			flags |= GLOB_APPEND;

		/* we've already  */
		glob(luaL_checkstring(L, i), flags, NULL, &g);
	}

	for (i = 0; i < g.gl_pathc; ++i) {
                lua_pushnumber(L, i+1);
		lua_pushstring(L, g.gl_pathv[i]);
		lua_settable(L, -3);
	}

	globfree(&g);
	return 1;
}
