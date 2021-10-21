/*	$Tom: zlib.c,v 1.1 2021/10/21 10:33:49 op Exp $	*/

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

#define CHUNK 8192
#define MIN(a, b)  ((a) < (b) ? (a) : (b))

#include <errno.h>
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

static int	zlib_inflate(lua_State *);

int
luaopen_zlib(lua_State *L)
{
	lua_newtable(L);

	lua_pushcfunction(L, zlib_inflate);
	lua_setfield(L, -2, "inflate");

	return 1;
}

static int
zlib_inflate(lua_State *L)
{
	FILE		*f, *src;
	z_stream	 strm;
	size_t		 len;
	int		 r, saved_errno;
	char		*buf, in[CHUNK], out[CHUNK];
	const char	*path, *err = NULL;

	path = luaL_checkstring(L, 1);

	if ((src = fopen(path, "r")) == NULL) {
		saved_errno = errno;
		lua_pushnil(L);
		lua_pushstring(L, strerror(saved_errno));
		return 2;
	}

	if ((f = open_memstream(&buf, &len)) == NULL) {
		saved_errno = errno;

		lua_pushnil(L);
		lua_pushstring(L, strerror(saved_errno));
		return 2;
	}

	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	strm.opaque = Z_NULL;
	strm.avail_in = 0;
	strm.next_in = Z_NULL;
	if ((r = inflateInit(&strm)) != Z_OK) {
		fclose(src);
		fclose(f);
		free(buf);
		luaL_error(L, "inflateInit error: #%d", r);
	}

	do {
		strm.avail_in = fread(in, 1, sizeof(in), src);
		if (ferror(src)) {
			fclose(src);
			fclose(f);
			free(buf);
			inflateEnd(&strm);
			luaL_error(L, "i/o error");
		}

		strm.next_in = in;
		do {
			strm.avail_out = sizeof(out);
			strm.next_out = out;

			switch (r = inflate(&strm, Z_NO_FLUSH)) {
			case Z_NEED_DICT:
				err = "need dictionary";
				break;
			case Z_DATA_ERROR:
				err = "data error";
				break;
			case Z_MEM_ERROR:
				err = "memory error";
				break;
			}

			if (err != NULL) {
				fclose(src);
				fclose(f);
				free(buf);
				inflateEnd(&strm);
				luaL_error(L, "inflate error: %s", err);
			}

			len = sizeof(out) - strm.avail_out;
			fwrite(out, 1, len, f);
			if (ferror(f)) {
				fclose(src);
				fclose(f);
				free(buf);
				inflateEnd(&strm);
				luaL_error(L, "inflate: memory error: %s",
				    strerror(ferror(f)));
			}
		} while (strm.avail_out == 0);
	} while (r != Z_STREAM_END);

	inflateEnd(&strm);
	fclose(src);
	fclose(f);

	lua_pushlstring(L, buf, len);
	free(buf);
	return 1;
}
