#!/bin/bash

# used to copy the source directory into a new where each instance gets its own files - prevent locks

CHAT_DATE=`date +%Y%m%d-%H%M%S-%N | cut -b1-21`
NEW_DIR=/home/ubuntu/.aichat-history/aichat-$CHAT_DATE
cp -r /home/ubuntu/.config/aichat/ $NEW_DIR

export AICHAT_CONFIG_DIR="$NEW_DIR"
/home/ubuntu/.cargo/bin/aichat --rag pc-rag-all --role airole-front-desk
