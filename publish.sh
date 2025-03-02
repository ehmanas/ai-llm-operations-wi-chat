#!/bin/bash

##NOTE: DO NOT EXPOSE THIS SERVER TO THE INTERNET!!! IT SHOULD BE HELD BEHIND A FIREWALL AND ONLY EXPOSED TO TRUSTED RESOURCES.
##NOTE: this script assumes debain 12 or ubuntu 24.04
##NOTE: this would normally be deployed in a nixos environment; however, creating a generic script is more accessible to most Linux users
##NOTE: this script has two parts: 
##		top part helps configure a server
##		bottom part is the script that runs evert time you publish
##NOTE: the top part is not really a script. It is designed to guide you. You can uncomment a section at a time to review and execute to configure your system.

##TODO: ensure running from user with sudo priviledges - assumes this is your primary user
##TODO: create a url for this server and update theme/head.hbs accordingly
##TODO: add https cert in nginx
##TODO: need openai and claude api tokens for aichat (open ai for embedding/rag and claude for general questions)
##TODO: script depends on a local user (rags, services, etc...) - if the desired user does not exist, simply create it with sudo capabilities
##TODO: update the below variables labeled with ###change-me###

#### Repository Notes ####
# The script assumes there are multiple repositories (or at least accounts for this scenario)
# each repository:
#	is a book or collection of knowledge (has src directory)
#	has its own book.toml
#		we can put [chuckstack] variables in the book.toml without conflict
#	can have multiple aichat airole files/ttyd (csr, mgr, etc...)
#### end Repository Notes ####

function graceful_exit
{
      echo -e "Exiting due to an error occuring at $(TZ=US/Eastern date '+%m/%d/%Y %H:%M:%S EST.')\n" | tee -a $LOG_FILE
      echo -e "Some results before the error may have been logged to $LOG_FILE\n"
      echo -e "Here is the error message: $1\n"
      exit 1
}

#validations
echo HERE validations
sudo ls &>/dev/null || graceful_exit "current user does not have sudo abilities"

#### Variables used by all parts of script ####
# create an array of properties that need to be written to a file later
declare -A SC_VARIABLES
#SC_VARIABLES[SOME_VARIABLE]="some-value"
# fully qualified script path and name
SC_SCRIPT_DIR_NAME=$(readlink -f "$0")
echo SC_SCRIPT_DIR_NAME=$SC_SCRIPT_DIR_NAME
# fully qualified script path
SC_SCRIPT_DIR=$(dirname "$SC_SCRIPT_DIR_NAME")
echo SC_SCRIPT_DIR=$SC_SCRIPT_DIR
# name of script
SC_SCRIPT_NAME=$(basename "$0")
echo SC_SCRIPT_NAME=$SC_SCRIPT_NAME
# Current User
OS_USER=$(id -u -n)
echo OS_USER=$OS_USER
# Current Group
OS_USER_GROUP=$(id -g -n)
echo OS_USER_GROUP=$OS_USER_GROUP
# chat user
CHAT_USER="cathy" ###change-me###
echo CHAT_USER=$CHAT_USER
SC_VARIABLES[CHAT_USER]=$CHAT_USER
# Where to install docs
WI_ROOT_DIR=/opt/work-instruction
echo WI_ROOT_DIR=$WI_ROOT_DIR
# git URL
GH_URL="https://github.com"
echo GH_URL=$GH_URL
# git project
GH_PROJECT="chuckstack" ###change-me###
echo GH_PROJECT=$GH_PROJECT
SC_VARIABLES[GH_PROJECT]=$GH_PROJECT
# git repo
GH_REPO="ai-llm-operations-wi-chat" ###change-me###
echo GH_REPO=$GH_REPO
SC_VARIABLES[GH_REPO]=$GH_REPO
# work instruction url
WI_URL=$GH_URL/$GH_PROJECT/$GH_REPO
echo WI_URL=$WI_URL
SC_VARIABLES[WI_URL]=$WI_URL
# work instruction source full path
WI_REPO_DIR=$WI_ROOT_DIR/$GH_PROJECT/$GH_REPO
echo WI_REPO_DIR=$WI_REPO_DIR
SC_VARIABLES[WI_REPO_DIR]=$WI_REPO_DIR
# where the markdown files are located
WI_SRC_DIR=$WI_REPO_DIR/"src-work-instructions" ###change-me###
echo WI_SRC_DIR=$WI_SRC_DIR
SC_VARIABLES[WI_SRC_DIR]=$WI_SRC_DIR
# AI role that tells your LLM how to answer questions
AI_ROLE_STARTER=airole-starter
echo AI_ROLE_STARTER=$AI_ROLE_STARTER
# AI role that tells your LLM how to answer questions
AI_ROLE_STARTER_MD=$AI_ROLE_STARTER.md
echo AI_ROLE_STARTER_MD=$AI_ROLE_STARTER_MD
# AI RAG Name for where all documents are maintained
AI_RAG_ALL=wi-rag-all
echo AI_RAG_ALL=$AI_RAG_ALL
# nginx website dir
WS_NGINX_DIR=$GH_PROJECT-$GH_REPO
echo WS_NGINX_DIR=$WS_NGINX_DIR
SC_VARIABLES[WS_NGINX_DIR]=$WS_NGINX_DIR
# ttyd port - one per repo/role - note that 7681 is the default
TTYD_PORT=7681
echo TTYD_PORT=$TTYD_PORT

echo
echo property variables:
for key in "${!SC_VARIABLES[@]}"; do
    echo "$key=\"${SC_VARIABLES[$key]}\""
done

#exit
#### end variables used by all parts of script ####

##NOTE: this might already be installed
#### install config system inside local user ####
##note: installs aichat, mdbook and other things needed to admin a machine for the current user - we install this on all machines - review if needed
#cd ~
#sudo apt update
#sudo apt install git
#git clone https://github.com/chuboe/chuboe-system-configurator
#cd chuboe-system-configurator/
#./init.sh
#### end config system ####

##NOTE: this secton needs to be deleted
#### create book repo artifacts ####
#sudo mkdir -p $WI_ROOT_DIR
#sudo chown $OS_USER:$OS_USER_GROUP $WI_ROOT_DIR
#cd $WI_ROOT_DIR
#git config --global credential.helper 'cache --timeout 7200000' #Note - better to use ssh key
#git clone $WI_URL # this is your obsidian repository
#cd $GH_REPO
#### end create book repo artifacts ####

#### Ensure proper Locale ####
##locale - important for `mdbook build` step
#sudo locale-gen en_US.UTF-8
#sudo update-locale LANG=en_US.UTF-8 LANGUAGE=en_US LC_ALL=en_US.UTF-8
##note: the below statements should help prevent from needing to disconned before continuing
#export LANG=en_US.UTF-8
#export LANGUAGE=en_US
#export LC_ALL=en_US.UTF-8
#### end ensure proper Locale ####

#### create local chat user ####
#sudo adduser --disabled-password --gecos "" $CHAT_USER
##sudo userdel $CHAT_USER; sudo rm -rf /home/$CHAT_USER/ # if needed during testing
#### end create local chat user ####

#### create /opt repositories
#sudo mkdir -p $WI_ROOT_DIR/$GH_PROJECT/
#sudo cp -r $SC_SCRIPT_DIR/ $WI_ROOT_DIR/$GH_PROJECT/
#### end create /opt repositories

#### start aichat configure ####
#cd $SC_SCRIPT_DIR
#sudo mkdir -p /home/$CHAT_USER/.config/aichat/roles/
#sudo cp util/config.yaml /home/$CHAT_USER/.config/aichat/.
#sudo ln -s $WI_SRC_DIR/$AI_ROLE_STARTER_MD /home/$CHAT_USER/.config/aichat/roles/$AI_ROLE_STARTER_MD
#echo manually add claude and openai keys to ~/.config/aichat/config.yaml
#echo run \`sudo -u $CHAT_USER aichat\` and send a test message to confirm all works as expected
#echo run \`sudo -u $CHAT_USER aichat --role $AI_ROLE_STARTER\` and send a test message to confirm the role works as expected
#### end aichat install ####

#### create RAG ####
## create a directory where we can ensure only the files we want ingested are present
#sudo mkdir -p $WI_REPO_DIR/rag-stage
#sudo cp $WI_SRC_DIR/*.md $WI_REPO_DIR/rag-stage/
#### end create RAG ####

##Here are the steps to build a local rag:
##note: `>` represents being in the aichat repl
##note: variables are not auto completed - they are just there to show you what should be added. example $AI_RAG_ALL could be 'wi-rag-all'
##```bash
#echo
#echo
#echo "### execute the following manually ###"
#echo
#echo
#echo sudo -u $CHAT_USER aichat
#echo "> .rag $AI_RAG_ALL"
#echo "> large embedding (default)"
#echo "> 2000 chunk (default)"
#echo "> 100 overlap (default)"
#echo "> $WI_REPO_DIR/rag-stage/**/*.md"
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

####HERE NEXT####
####create dedicated util script to move identified files to rag-stage directory - add to Create RAG section abvoe
####create variable above for ttyd service name
#### start ttyd service ####
##TODO: update $WI_ROOT_DIR/util/ttyd.service to reflect $OS_USER (may not be debian - replace all instances)
##NOTE: consider creating an unpriviledged user (other than $OS_USER) - not super important since aichat repl jails the user experience...
#sudo cp $WI_ROOT_DIR/util/ttyd.service /etc/systemd/system/.
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
##TODO: add IP/URL to variable above
##edit theme/head.hbs to reflect url
#### end update mdbook with url to ttyd ####

######## END PART ONE: Configuration ##########

######### START PART TWO: PUBLISH ##########
###NOTE: the following is uncommented and added to a cron for periodic execution
#
#PUBLISH_DATE=`date +%Y%m%d`-`date +%H%M%S`
#echo "**********************"
#echo "***starting publish***"
#echo "**********************"
#echo PUBLISH_DATE = $PUBLISH_DATE
#cd ~/pc-work-instruction/
#cd pc-work-instruction && ./summary.sh && cd ..
#git add .
#git commit -m 'publisher commit summary'
#git pull --rebase
#/home/ubuntu/.cargo/bin/mdbook build
#sudo rsync -a --delete book/ /var/www/procare-ws/
#sudo chown -R www-data:www-data /var/www/procare-ws/
#sudo rm -rf /var/www/procare-ws/.obsidian/
##sudo systemctl restart ttyd
##sudo systemctl restart nginx
#
## Create or clear the output file - prepare to cat all individual chat result directories
#OUTPUT_FILE=~/.config/aichat/messages.md
#> "$OUTPUT_FILE"
#
## Find all individual messages.md files and cat them into the output file
#find ~/.aichat-history/ -name "messages.md" -type f -exec cat {} >> "$OUTPUT_FILE" \;
#
## evaluate combined messages
#/home/ubuntu/.cargo/bin/aichat --no-stream -f pc-work-instruction/airole-message-review.md -f $OUTPUT_FILE
#
## rebuild the rag with current files
#rm -rf ~/pc-work-instruction/rag-stage/*
#cp ~/pc-work-instruction/pc-work-instruction/*.md ~/pc-work-instruction/rag-stage/.
#rm ~/pc-work-instruction/rag-stage/SUMMARY.md
#/home/ubuntu/.cargo/bin/aichat --rag pc-rag-all --rebuild-rag
#
## move messages to chat history
#mv $OUTPUT_FILE ./pc-work-instruction/prompt-history/messages-$PUBLISH_DATE.md
#
## git it
#git add .
#git commit -m 'publisher commit prompt history'
#git pull --rebase
#git push
#
## cleanup history
#rm -rf /home/ubuntu/.aichat-history/*
#
#echo "***ending publish***"
#
##### deploy aichat through ttyd
##ttyd -a -W aichat --session --rag pc-wi --role pc-role-fd
