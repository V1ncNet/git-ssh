#!/bin/sh
if [ "$#" -ne 2 ]; then
    exec /usr/local/libexec/git-lfs-transfer "$@"
fi
path=$1
case $path in
    "/~" | "~") path=$HOME ;;
    "/~/"*) path=$HOME/${path#"/~/"} ;;
    "~/"*) path=$HOME/${path#"~/"} ;;
esac
if [ ! -e "$path" ] && [ -d "$path.git" ]; then
    path=$path.git
fi
exec /usr/local/libexec/git-lfs-transfer "$path" "$2"
