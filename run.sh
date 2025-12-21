#!/usr/bin/env bash

set -e
DIR=$(realpath $0) && DIR=${DIR%/*}
cd $DIR/conf/gitsync
shopt -s nullglob
for f in *.env; do
  # `>&2` 避免 github action 日志缓冲导致输出错乱
  echo "$f" >&2
  set -a
  source "$f"
  set +a
done
set -x
cd $DIR
./main.js
