-- $Tom: view.lua,v 1.1 2021/10/21 10:33:49 op Exp $
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

local view = {}

local fs = require "fs"
local git = require "git"
local mime = require "mime"

local function fmt_datetime(d)
   return string.format("%d-%02d-%02d %02d:%02d",
                        d.year, d.month, d.day, d.hour, d.min)
end

local function fmt_date(d)
   return string.format("%d-%02d-%02d", d.year, d.month, d.day)
end

function view.reply(code, meta)
   io.write(code .. " " .. meta .. "\r\n")
   if code ~= 20 then
      os.exit(0)
   end
end

function view:openrepo(name)
   self.repo = git.open(self.dir.."/"..name)
   if not self.repo then
      return view.reply(51, "not found")
   end

   self.rawname = name
   self.name = string.gsub(name, "\\.git$", "")
end

function view:url(rel)
   return string.format("%s/%s", self.base, rel)
end

function view:rurl(rel)
   return self:url(self.rawname.."/"..rel)
end

function view:home()
   view.reply(20, "text/gemini")

   print("Projects:")
   print("")

   local any = false
   for f in fs.dirs(self.dir) do
      if f ~= "." and f ~= ".." then
         any = true
         print("=> "..self:url(f.."/").." "..f)
      end
   end

   if not any then
      print("No projects (yet)")
   end
end

function view:repo(name)
   self:openrepo(name)

   view.reply(20, "text/gemini")
   print("# "..self.name)
   print()

   local descr = self.repo:description() or ""
   descr = string.gsub(descr, "^", "> ")
   print(descr)

   if view.cloneurl then
      print("``` To clone this repository execute")
      print("git clone "..view.cloneurl.."/"..self.rawname)
      print("```")
      print()
   end

   print("=> "..self:rurl("branches").." branches")
   print("=> "..self:rurl("tags").." tags")

   print()
   print("### Files")
   print()

   local t = self.repo:tree()
   for _, entry in ipairs(t.tree) do
      print("=> tree/".. entry.path.." "..entry.path)
   end
end

function view:commit(name, commit)
   self:openrepo(name)

   local c = self.repo:object(commit)
   if not c or c.type ~= "commit" then
      return view.reply(51, "not found")
   end

   view.reply(20, "text/gemini")

   print("# "..self.name.." - commit "..commit)
   print()

   local hasparent = #c.parents
   for _, parent in ipairs(c.parents) do
      print("=> "..parent.." parent: "..parent)
   end

   if hasparent then
      print()
   else
      print("No parent commit")
      print()
   end

   if c.date then
      print("Date: "..fmt_datetime(c.date))
   end
   if c.author then
      print("Author: "..c.author)
   end
   if c.committer then
      print("Committer: "..c.committer)
   end
   print()

   -- XXX escape ``` at least
   print("```Commit message")
   print(c.message or "")
   print("```")

   -- TODO: show diff!
end

function view:tree(name, path, ref)
   self:openrepo(name)

   local f, err = self.repo:findfile(path)
   if err then
      io.stderr:write("can't open "..path..": "..err)
      return view.reply(51, "not found")
   end

   if f.type == "blob" then
      local filename = string.gsub(path, "^.*/", "")
      view.reply(20, mime:detect(filename))
      io.stdout:write(f.data)
   elseif f.type == "tree" then
      if path ~= "" and not string.find(path, "/", -1) then
         return view.reply(30, self:rurl("tree/"..path.."/"))
      end

      view.reply(20, "text/gemini")
      print("# "..self.name.." - tree of "..path)
      print()

      if path ~= "" then
         print("=> ..")
      end

      for _, entry in ipairs(f.tree) do
         print("=> "..entry.path)
      end
   else
      io.stderr:write("don't know how to render object type "..(f.type))
      return view.reply(51, "not found")
   end
end

function view:branches(name)
   self:openrepo(name)

   view.reply(20, "text/gemini")
   print("# "..self.name.." - branches")
   print()

   local branches = self.repo:branches()
   if #branches then
      for _, branch in ipairs(branches) do
         local c = self.repo:resolve_branch(branch)
         print("=> "..self:rurl("commit/"..c).." "..branch.." ("..c..")")
      end
   else
      print("No branches")
   end
end

function view:tags(name)
   self:openrepo(name)

   view.reply(20, "text/gemini")

   print("# "..self.name.." - tags")
   print()

   local tags = self.repo:tags()
   if #tags then
      for _, tag in ipairs(tags) do
         local url
         local date

         if not tag.object then
            url = ""
            date = "<unknown>"
         elseif tag.object.type == "commit" then
            url = self:rurl("commit/"..tag.object.myref)
            date = fmt_date(tag.object.date)
         elseif tag.object.type == "tag" then
            url = self:rurl("tag/"..tag.name)
            date = fmt_date(tag.object.date)
         end

         print("=> "..url.." "..date.." - "..tag.name)
      end
   else
      print("No tags")
   end
end

function view:tag(name, tagname)
   self:openrepo(name)

   local t = self.repo:resolve_tag(tagname)
   local tag = self.repo:object(t)
   if not t then
      return view.reply(51, "not found")
   end

   view.reply(20, "text/gemini")

   print("# "..self.name.." - tag "..tagname)
   print()

   if tag.date then
      print("Date: "..fmt_datetime(tag.date))
   end
   if tag.tagger then
      print("Tagger: "..tag.tagger)
   end
   print()

   -- XXX escape ``` at least
   print("```Message")
   print(tag.message or "")
   print("```")
end

function view:notfound()
   view.reply(51, "not found")
end

function view:error(str)
   view.reply(51, str)
end

return view
