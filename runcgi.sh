#!/bin/sh
#
# $Tom: runcgi.sh,v 1.1 2021/10/21 10:33:49 op Exp $
#
# runcgi.sh: simulate a CGI execution
#
# USAGE: ./runcgi.sh [path]
#
# path is "/" if omitted.

# tom's configuration variables
export TOM_REPOS_DIR=${TOM_REPOS_DIR:-"/home/op/git/"}

# cgi stuff
export GATEWAY_INTERFACE="CGI/1.1"
export PATH_INFO="${1:-/}"
export SCRIPT_NAME=

# lift off!
exec lua53 tom.lua
