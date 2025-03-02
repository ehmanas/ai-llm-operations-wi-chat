#!/bin/bash

# fully qualified script path and name
SC_SCRIPT_DIR_NAME=$(readlink -f "$0")
echo SC_SCRIPT_DIR_NAME=$SC_SCRIPT_DIR_NAME
# fully qualified script path
SC_SCRIPT_DIR=$(dirname "$SC_SCRIPT_DIR_NAME")
echo SC_SCRIPT_DIR=$SC_SCRIPT_DIR

cd $SC_SCRIPT_DIR

source ../config.properties

sudo mkdir -p $WI_REPO_DIR/rag-stage
sudo cp $WI_SRC_DIR/*.md $WI_REPO_DIR/rag-stage/
