#!/bin/bash

##NOTE: DO NOT EXPOSE THIS SERVER TO THE INTERNET!!! IT SHOULD BE HELD BEHIND A FIREWALL AND ONLY EXPOSED TO TRUSTED RESOURCES.
##NOTE: this script assumes debain 12 or ubuntu 24.04
##NOTE: this would normally be deployed in a nixos environment; however, creating a generic script is more accessible to most Linux users
##NOTE: this script has two parts: 
##		top part helps configure a server
##		bottom part is the script that runs evert time you publish
##NOTE: the top part is not really a script. It is designed to guide you. You can uncomment a section at a time to review and execute.

##TODO: ensure running from user with sudo priviledges - assumes this is your primary user
##TODO: create a url for this server and update theme/head.hbs accordingly
##TODO: add https cert in nginx
##TODO: need openai and claude api tokens for aichat (open ai for embedding/rag and claude for general questions)
##TODO: script depends on a local user (rags, services, etc...) - if the desired user does not exist, simply create it with sudo capabilities
##TODO: update the below variables labeled with ###change-me###


#### Variables used by all parts of script ####
# Where to install docs
WI_DIR=/opt/work-instruction
echo WI_DIR=$WI_DIR
# Current User
OS_USER=$(id -u -n)
echo OS_USER=$OS_USER
# Current Group
OS_USER_GROUP=$(id -g -n)
echo OS_USER_GROUP=$OS_USER_GROUP
# git URL
GH_URL="https://github.com"
echo GH_URL=$GH_URL
# git project
GH_PROJECT="your-project" ###change-me###
echo GH_PROJECT=$GH_PROJECT
# git repo
GH_REPO="your-repo" ###change-me###
echo GH_REPO=$GH_REPO
# work instruction url
WI_URL=$GH_URL/$GH_PROJECT/$GH_REPO/
echo WI_URL=$WI_URL
# work instruction source - where Obsidian saves markdown work instructions
WI_SRC=src-work-instructions ###sync with book.toml, .gitignore if changed###
echo WI_SRC=$WI_SRC
# work instruction source full path
WI_SRC_DIR=$WI_DIR/$GH_REPO/$WI_SRC
echo WI_SRC_DIR=$WI_SRC_DIR
# AI role that tells your LLM how to answer questions
AI_ROLE_STARTER=airole-starter.md
echo AI_ROLE_STARTER=$AI_ROLE_STARTER
# AI RAG Name for where all documents are maintained
AI_RAG_ALL=wi-rag-all
echo AI_RAG_ALL=$AI_RAG_ALL
# nginx website dir
WS_NGINX_DIR=wi-website
echo WS_NGINX_DIR=$WS_NGINX_DIR

#exit
#### end variables used by all parts of script ####

#### Ensure proper Locale ####
##locale - important for `mdbook build` step
#sudo locale-gen en_US.UTF-8
#sudo update-locale LANG=en_US.UTF-8 LANGUAGE=en_US LC_ALL=en_US.UTF-8
##note: the below statements should help prevent from needing to disconned before continuing
#export LANG=en_US.UTF-8
#export LANGUAGE=en_US
#export LC_ALL=en_US.UTF-8
#### end ensure proper Locale ####

#### install config system inside local user ####
##note: installs aichat, mdbook and other things needed to admin a machine for the current user - we install this on all machines - review if needed
#cd ~
#sudo apt update
#sudo apt install git
#git clone https://github.com/chuboe/chuboe-system-configurator
#cd chuboe-system-configurator/
#./init.sh
#### end config system ####

#### create book repo artifacts ####
#sudo mkdir -p $WI_DIR
#sudo chown $OS_USER:$OS_USER_GROUP $WI_DIR
#cd $WI_DIR
#git config --global credential.helper 'cache --timeout 7200000' #Note - better to use ssh key
#git clone $WI_URL # this is your obsidian repository
#cd $GH_REPO
#### end create book repo artifacts ####

#### start aichat configure ####
#cd ~
#mkdir -p ~/.config/aichat/roles/
#cp $WI_SRC_DIR/util/config.yaml ~/.config/aichat/.
#cd ~/.config/aichat/roles/
#ln -s $WI_SRC_DIR/$AI_ROLE_STARTER $AI_ROLE_STARTER
##TODO: manually add claude and openai keys to ~/.config/aichat/config.yaml
##TODO: run `aichat` and send a test message to confirm all works as expected
##TODO: run `aichat --role $AI_ROLE_STARTER` and send a test message to confirm the role works as expected
#### end aichat install ####

#### create RAG ####
# create a directory where we can ensure only the files we want ingested are present
#mkdir -p $WI_DIR/rag-stage
#cp $WI_SRC_DIR/*.md $WI_DIR/rag-stage/

##Here are the steps to build a local rag:
##note: `>` represents being in the aichat repl
##note: variables are not auto completed - they are just there to show you what should be added. example $AI_RAG_ALL could be 'wi-rag-all'
##```bash
#echo AI_RAG_ALL=$AI_RAG_ALL
#echo rag directory = $WI_DIR/rag-stage/\*\*/\*.md
#aichat
#> .rag $AI_RAG_ALL
#> large embedding (default)
#> 2000 chunk (default)
#> 100 overlap (default)
#> $WI_DIR/rag-stage/**/*.md
##```
##TODO: run `aichat --role $AI_ROLE_STARTER --rag $AI_RAG_ALL` and send a test message to confirm the role and rag work together as expected
#### end create RAG ####

#### start ttyd installation ####
#cd /tmp/
#sudo apt-get update
#sudo apt-get install -y build-essential cmake git libjson-c-dev libwebsockets-dev
#git clone https://github.com/tsl0922/ttyd.git
#cd ttyd && mkdir build && cd build
#cmake ..
#make && sudo make install
#### end ttyd installation ####

#### start ttyd service ####
##TODO: update $WI_DIR/util/ttyd.service to reflect $OS_USER (may not be debian - replace all instances)
##NOTE: consider creating an unpriviledged user (other than $OS_USER) - not super important since aichat repl jails the user experience...
#sudo cp $WI_DIR/util/ttyd.service /etc/systemd/system/.
#sudo systemctl daemon-reload
#sudo systemctl enable ttyd
#sudo systemctl start ttyd
##sudo journalctl -u ttyd #show logs for ttyd
#### end ttyd service ####

#### start init config of nginx - part 1 ####
#sudo apt install nginx -y
#echo WS_NGINX_DIR=$WS_NGINX_DIR
#sudo mkdir -p /var/www/$WS_NGINX_DIR
#sudo chown -R www-data:www-data /var/www/$WS_NGINX_DIR/
#sudo chmod -R 755 /var/www/$WS_NGINX_DIR/
#sudo touch /etc/nginx/sites-available/$WS_NGINX_DIR
#### end init config of nginx - part 1 ####

	##TODO: add the following to /etc/nginx/sites-available/$WS_NGINX_DIR
	##TODO: change $WS_NGINX_DIR to the actual value

	#server {
	#    listen 80;
	#    listen [::]:80;
	#
	#    server_name your-domain.com www.your-domain.com;
	#    root /var/www/$WS_NGINX_DIR;
	#    index index.html index.htm;
	#
	#    location / {
	#        try_files $uri $uri/ =404;
	#    }
	#
	#    location /ttyd/ {
	#        proxy_http_version 1.1;
	#        proxy_set_header Host $host;
	#        proxy_set_header X-Forwarded-Proto $scheme;
	#        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	#        proxy_set_header Upgrade $http_upgrade;
	#        proxy_set_header Connection "upgrade";
	#        proxy_pass http://127.0.0.1:7681/;
	#    }
	#}
	##Notes: root(/) is book and /ttyd is terminal

#### start init config of nginx - part 2 ####
#sudo ln -s /etc/nginx/sites-available/$WS_NGINX_DIR /etc/nginx/sites-enabled/
#sudo rm /etc/nginx/sites-enabled/default
#sudo systemctl restart nginx
#### end init config of nginx - part 2 ####

#### start update mdbook with url to ttyd ####
##edit theme/head.hbs to reflect url
#### end update mdbook with url to ttyd ####

######## END PART ONE: Configuration ##########

######## START PART TWO: PUBLISH ##########
##NOTE: the following is uncommented and added to a cron for periodic execution

PUBLISH_DATE=`date +%Y%m%d`-`date +%H%M%S`
echo "**********************"
echo "***starting publish***"
echo "**********************"
echo PUBLISH_DATE = $PUBLISH_DATE
cd ~/pc-work-instruction/
cd pc-work-instruction && ./summary.sh && cd ..
git add .
git commit -m 'publisher commit summary'
git pull --rebase
/home/ubuntu/.cargo/bin/mdbook build
sudo rsync -a --delete book/ /var/www/procare-ws/
sudo chown -R www-data:www-data /var/www/procare-ws/
sudo rm -rf /var/www/procare-ws/.obsidian/
#sudo systemctl restart ttyd
#sudo systemctl restart nginx

# Create or clear the output file - prepare to cat all individual chat result directories
OUTPUT_FILE=~/.config/aichat/messages.md
> "$OUTPUT_FILE"

# Find all individual messages.md files and cat them into the output file
find ~/.aichat-history/ -name "messages.md" -type f -exec cat {} >> "$OUTPUT_FILE" \;

# evaluate combined messages
/home/ubuntu/.cargo/bin/aichat --no-stream -f pc-work-instruction/airole-message-review.md -f $OUTPUT_FILE

# rebuild the rag with current files
rm -rf ~/pc-work-instruction/rag-stage/*
cp ~/pc-work-instruction/pc-work-instruction/*.md ~/pc-work-instruction/rag-stage/.
rm ~/pc-work-instruction/rag-stage/SUMMARY.md
/home/ubuntu/.cargo/bin/aichat --rag pc-rag-all --rebuild-rag

# move messages to chat history
mv $OUTPUT_FILE ./pc-work-instruction/prompt-history/messages-$PUBLISH_DATE.md

# git it
git add .
git commit -m 'publisher commit prompt history'
git pull --rebase
git push

# cleanup history
rm -rf /home/ubuntu/.aichat-history/*

echo "***ending publish***"

#### deploy aichat through ttyd
#ttyd -a -W aichat --session --rag pc-wi --role pc-role-fd
