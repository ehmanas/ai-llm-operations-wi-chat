#!/bin/bash

source $WI_REPO_DIR/config.properties

sudo mkdir -p $WI_REPO_DIR/rag-stage
sudo cp $WI_SRC_DIR/*.md $WI_REPO_DIR/rag-stage/
