-- $Tom: mime.lua,v 1.1 2021/10/21 10:33:49 op Exp $
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

-- XXX: use libmagic as fallback?

local mime = {
   well_known = {
      ["[.]c$"] = "text/x-c",
      ["[.]h$"] = "text/x-c",

      ["[.]cc$"] = "text/x-cpp",
      ["[.]cpp$"] = "text/x-cpp",
      ["[.]hh$"] = "text/x-cpp",
      ["[.]hpp$"] = "text/x-cpp",

      ["[.]lua$"] = "text/x-lua",

      ["[.]sh"] = "text/x-sh",

      ["[.]md$"] = "text/markdown",
      ["[.]markdown$"] = "text/markdown",

      ["[.]gmi$"] = "text/gemini",
      ["[.]gemini$"] = "text/gemini",

      ["^Makefile$"] = "text/x-makefile",
      ["^Makefile.am$"] = "text/x-makefile",
      ["^Makefile.in$"] = "text/x-makefile",
      ["^makefile$"] = "text/x-makefile",
      ["^GNUMakefile$"] = "text/x-makefile",
      ["^gnumakefile$"] = "text/x-makefile",
      ["[.]mk$"] = "text/x-makefile",

      ["[.]gitignore$"] = "text/plain",

      ["[.]txt$"] = "text/plain",
      ["^README$"] = "text/plain",

      -- ...
   }
}

function mime:detect(filename)
   for pattern, mime in pairs(self.well_known) do
      if string.match(filename, pattern) then
         return mime
      end
   end

   return "application/octet-stream"
end

return mime
