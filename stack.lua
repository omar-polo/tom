-- $Tom: stack.lua,v 1.1 2021/10/21 10:33:49 op Exp $
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

local table = require "table"

local stack = {}
stack.__index = stack

function stack.new()
   local s = {
      elements = {},
   }
   setmetatable(s, stack)
   return s
end

function stack:push(x)
   table.insert(self.elements, x)
end

function stack:pop()
   if #self.elements == 0 then
      return nil
   end
   local x = self.elements[#self.elements]
   table.remove(self.elements)
   return x
end

function stack:empty()
   return #self.elements == 0
end

return stack
