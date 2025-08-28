#!/bin/bash

# used to copy the source directory into a new where each instance gets its own files - prevent locks

CHAT_DATE=`date +%Y%m%d-%H%M%S-%N | cut -b1-21`
NEW_DIR=/home/debian/.aichat-history/aichat-$CHAT_DATE
mkdir -p /home/debian/.aichat-history/
cp -r /home/debian/.config/aichat/ $NEW_DIR

# $1 is the argument passed into ttyd and ultimately this script
echo arg=$1 >> /tmp/out.txt
export STK_ARG1=$1

export AICHAT_CONFIG_DIR="$NEW_DIR"
/usr/local/bin/aichat --rag wi-rag-all --role airole-starter
