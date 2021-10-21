-- $Tom: git.lua,v 1.1 2021/10/21 10:33:49 op Exp $
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

local fs = require "fs"
local zlib = require "zlib"
local stack = require "stack"
local gitc = require "gitc"

local git = {}
git.__index = git

local repo = {}
repo.__index = repo

local object = {}
object.__index = object

local function readall(path)
   local f, err = io.open(path)
   if f == nil then
      return nil, err
   end
   local len = f:seek("end")
   f:seek("set", 0)
   local content = f:read(len)
   f:close()
   return content
end

function git.open(path)
   local r = {
      path = path
   }
   setmetatable(r, repo)

   -- if not r:head() then
   --    return nil
   -- end

   return r
end

--- open and parse the packed-refs file
-- Not all the refs are under refs/*.  Git can (and usually does)
-- "pack" the references together in a single file.
function repo:packed_refs()
   -- use the cached result
   if self.refs then
      return self.refs
   end

   local c, err = readall(self.path.."/packed-refs")
   if not c then
      return nil, err
   end

   self.refs = {}

   for sha, ref in c:gmatch("(%w+) (.-)\n") do
      self.refs[ref] = sha
   end

   return self.refs
end

function repo:description()
   return readall(self.path .. "/" .. "description")
end

function repo:head()
   local head = readall(self.path .. "/HEAD")
   if not head then
      return nil
   end
   head = string.match(head, "ref: (.*)\n")
   head = readall(self.path.."/"..head)
   if head then
      return head:gsub("\n", "")
   end
end

function repo:tags()
   local tags = {}
   for t in fs.ls(self.path.."/refs/tags/") do
      if t ~= "." and t ~= ".." then
         local tag = self:resolve_tag(t)
         if tag then
            local p = {
               name = t,
               object = self:object(tag),
            }
            table.insert(tags, p)
         end
      end
   end

   table.sort(
      tags,
      function (t1, t2)
         if not t1.object or not t2.object then
            return t1.name < t2.name
         end
         return t1.object.date.raw < t2.object.date.raw
      end
   )

   return tags
end

function repo:resolve_tag(tag)
   local c, err = readall(self.path.."/refs/tags/"..tag)
   if c then
      return c:gsub("\n", "")
   end
   return nil, err
end

function repo:branches()
   local b = {}
   local s = stack.new()
   local prefix = self.path.."/refs/heads/"

   s:push(prefix)
   while not s:empty() do
      local x = s:pop()
      for _, f in ipairs(fs.glob(x.."*")) do
         if string.match(f, "/", -1) then
            s:push(f)
         else
            table.insert(b, string.sub(f, #prefix+1))
         end
      end
   end

   return b
end

function repo:resolve_branch(branch)
   local c, err = readall(self.path.."/refs/heads/"..branch)
   if c then
      return c:gsub("\n", "")
   end
   return nil, err
end

function repo:rawobject(ref)
   local p = string.sub(ref, 1, 2).."/"..string.sub(ref, 3)
   local obj = zlib.inflate(self.path.."/objects/"..p)
   return object.raw(self, obj)
end

function repo:object(ref)
   local obj = self:rawobject(ref)
   if obj then
      obj.myref = ref
      return obj:parse()
   end
end

local function splitdata(data)
   local p = string.find(data, "\n\n")
   local hdr = string.sub(data, 1, p)
   local body = string.sub(data, p+2)
   return hdr, body
end

local function parse_author(line)
   local author, date, _ = string.match(line, "(.* <.*>) (%d+) (.*)")

   -- ignore the time zone for now

   local d = os.date("!*t", date)
   d.raw = date
   return author, d
end

local function trim(str)
   local s = string.gsub(str, "^%s+", "")
   return string.gsub(s, "%s+$", "")
end

--- return the tree associated with ref
-- If ref is nil, use the repo' HEAD.  The returned tree is a table
-- that holds subtables for each file.
function repo:tree(ref)
   if not ref then
      ref = self:head()
   end

   local obj = self:object(ref)
   if not obj then
      return nil
   end

   if obj.type == "commit" then
      return self:object(obj.tree)
   end

   if obj.type == "tree" then
      return obj
   end
end

--- find the file identified by path in the repo
-- ref identifies the reference for the tree, if nil use the repo'
-- HEAD.
function repo:findfile(path, ref)
   local t = self:tree(ref or self:head())
   if not t then
      return nil, "can't open tree for ref: "..ref
   end

   -- traverse the file tree until we find the file
   while path ~= "" do
      local sep = string.find(path, "/")
      local file = path
      if sep then
         file = string.sub(path, 1, sep - 1)
         path = string.sub(path, sep + 1)
      else
         path = ""
      end

      local entry
      t, entry = t:findfile(file)
      if not t then
         return nil, "no file named "..file.." found"
      end

      local isdir = (entry.mode >> 12) == 0x4
      if not isdir and path ~= "" then
         return nil, file.." is not a directory"
      end
   end

   return t
end

function object.raw(repo, data)
   if not data then
      return nil
   end

   local type = string.match(data, "%l+")
   local len = string.match(data, "%d+", #type+1)

   local o = {
      repo = repo,
      type = type,
      len = len,
      data = string.sub(data, string.len(type) + string.len(len) + 3),
   }
   setmetatable(o, object)
   return o
end

function object:parse()
   if self.type == "tree" then
      self.tree = gitc.parsetree(self.data)
   elseif self.type == "commit" then
      local hdr, body = splitdata(self.data)

      self.message = trim(body)
      self.tree = string.match(hdr, "tree (%w+)")

      self.parents = {}
      for parent in string.gmatch(hdr, "parent (%w+)") do
         table.insert(self.parents, parent)
      end

      local committer string.match(hdr, "committer (.-)\n")
      if committer then
         self.committer, self.date = parse_author(author)
      end

      local author = string.match(hdr, "author (.-)\n")
      if author then
         self.author, self.date = parse_author(author)
      end
   elseif self.type == "tag" then
      local hdr, body = splitdata(self.data)

      self.message = trim(body)

      self.tag = string.match(hdr, "tag (.-)\n")
      local tagger = string.match(hdr, "tagger (.-)\n")
      -- print("tagger is", tagger)
      self.tagger, self.date = parse_author(tagger)
   end

   return self
end

--- find `name` (which can be a pattern) in the current tree
-- If found, return the associated git object.  If `pattern` is true,
-- consider `name` a pattern for matching purposes.  Returns the
-- object found and the tree entry.
function object:findfile(name, pattern)
   if self.type ~= "tree" then
      return nil
   end

   for _, entry in ipairs(self.tree) do
      if pattern and string.match(entry.path, name) then
         return self.repo.object(self.repo, entry.ref), entry
      elseif not pattern and entry.path == name then
         return self.repo.object(self.repo, entry.ref), entry
      end
   end
end

return git
