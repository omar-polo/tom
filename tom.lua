#!/usr/bin/env lua53

-- $Tom: tom.lua,v 1.1 2021/10/21 10:33:49 op Exp $
--
-- Copyright (c) 2021 Omar Polo <op@omarpolo.com>
--
-- Permission to use, copy, modify, and distribute this software for any
-- purpose with or without fee is hereby granted, provided that the above
-- copyright notice and this permission notice appear in all copies.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
-- WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
-- MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
-- ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
-- WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
-- ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
-- OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

local openbsd = require "openbsd"
local router = require "router"
local view = require "view"

if os.getenv("GATEWAY_INTERFACE") ~= "CGI/1.1" then
   error("GATEWAY_INTERFACE is not defined.  Not running as a CGI script?")
end

view.cloneurl = os.getenv("TOM_CLONE_URL")

view.dir = os.getenv("TOM_REPOS_DIR") or error("TOM_REPOS_DIR is unset")
view.path = os.getenv("PATH_INFO") or "/"
view.base = os.getenv("SCRIPT_NAME") or error("missing SCRIPT_NAME")

-- no-op on other OSes
openbsd.unveil(view.dir, "r")
openbsd.pledge("stdio rpath", nil)

router:register(
   "/",
   function ()
      view:home()
   end
)

router:register(
   "/([^/]+)/",
   function (m)
      view:repo(m[1])
   end
)

router:register(
   "/([^/]+)/commit/([A-Za-z0-9]+)",
   function (m)
      view:commit(m[1], m[2])
   end
)

router:register(
   "/([^/]+)/tree/(.*)",
   function (m)
      view:tree(m[1], m[2])
   end
)

router:register(
   "/([^/]+)/branches",
   function (m)
      view:branches(m[1])
   end
)

router:register(
   "/([^/]+)/tags",
   function (m)
      view:tags(m[1])
   end
)

router:register(
   "/([^/]+)/tag/(.*)",
   function (m)
      view:tag(m[1], m[2])
   end
)

router:register(nil, function () view:notfound() end)

local ok, err = pcall(router.dispatch, router, view.path)
if ok == false then
   local msg = string.format("catched error handling %s: %s", view.path, err)
   io.stderr:write(msg)
   view:error("can you hear me, major tom?")
end
