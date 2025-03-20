#!/bin/bash

##NOTE: DO NOT EXPOSE THIS SERVER TO THE INTERNET!!! IT SHOULD BE HELD BEHIND A FIREWALL AND ONLY EXPOSED TO TRUSTED RESOURCES.
##NOTE: this script assumes debain 12 or ubuntu 24.04
##NOTE: this would normally be deployed in a nixos environment; however, creating a generic script is more accessible to most Linux users
##NOTE: this script has two parts: 
##		top part helps configure a server ("init")
##		bottom part is the script that runs evert time you publish ("rebuild")
##NOTE: this script configures nginx and mdbook with IP. You will need to update with url if needed (see theme/head.hbs)

#### Here are the actions you need to either do or consider
##TODO: run https://github.com/chuboe/chuboe-system-configurator - installs prerequisite tools (like mdbook and aichat)
##TODO: ensure running from user with sudo priviledges - assumes this is your primary user
##TODO: add https cert in nginx
##TODO: update the below variables labeled with ###change-me###. Note: will run as is if testing

#### More Repository Notes ####
# The script assumes there are multiple repositories (or at least accounts for this scenario)
# each repository:
#	is a book or collection of knowledge (has src directory)
#	has its own book.toml
#		note that we can put [chuckstack] variables in the book.toml without conflict
#	can have multiple aichat airole files/ttyd (csr, mgr, etc...)
#### end More Repository Notes ####

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
# name of the book src directory
WI_SRC="src-work-instructions" ###change-me###
echo WI_SRC=$WI_SRC
SC_VARIABLES[WI_SRC]=$WI_SRC
# full path where the markdown files are located
WI_SRC_DIR=$WI_REPO_DIR/$WI_SRC
echo WI_SRC_DIR=$WI_SRC_DIR
SC_VARIABLES[WI_SRC_DIR]=$WI_SRC_DIR
# AI config to use (options: config-openai.yaml or config-claude.yaml) ###change-me###
AI_CONFIG=config-openai.yaml
# AI role that tells your LLM how to answer questions
AI_ROLE_STARTER=airole-starter
echo AI_ROLE_STARTER=$AI_ROLE_STARTER
# AI role that tells your LLM how to answer questions
# TODO: make this an array of all AI_ROLEs (not just one)
AI_ROLE_STARTER_MD=$AI_ROLE_STARTER.md
echo AI_ROLE_STARTER_MD=$AI_ROLE_STARTER_MD
# AI RAG Name for where all documents are maintained
AI_RAG_ALL=wi-rag-all
echo AI_RAG_ALL=$AI_RAG_ALL
# nginx website dir service name
WS_SERVICE_NAME=$GH_REPO-$AI_ROLE_STARTER
echo WS_SERVICE_NAME=$WS_SERVICE_NAME
SC_VARIABLES[WS_SERVICE_NAME]=$WS_SERVICE_NAME
# ttyd service name
WS_SERVICE_NAME_TTYD=ttyd-$WS_SERVICE_NAME
echo WS_SERVICE_NAME_TTYD=$WS_SERVICE_NAME_TTYD
SC_VARIABLES[WS_SERVICE_NAME]=$WS_SERVICE_NAME
# ttyd port - one per repo/role - note that 7681 is the default
TTYD_PORT=7681
echo TTYD_PORT=$TTYD_PORT
# your primary IP
MY_IP=$(hostname -I | awk '{print $1}')
echo MY_IP=$MY_IP

echo
echo property variables:
for key in "${!SC_VARIABLES[@]}"; do
    echo "$key=\"${SC_VARIABLES[$key]}\""
done
echo
#### end variables used by all parts of script ####

####remove stuff during testing
#sudo systemctl disable $WS_SERVICE_NAME.service
#sudo systemctl stop $WS_SERVICE_NAME.service
#sudo rm -rf /etc/systemd/system/$WS_SERVICE_NAME.service
#sudo systemctl daemon-reload
#sudo rm -rf /var/www/$WS_SERVICE_NAME
#sudo rm -f /etc/nginx/sites-available/$WS_SERVICE_NAME
#sudo rm /etc/nginx/sites-enabled/$WS_SERVICE_NAME
#sudo rm -rf /opt/work-instruction/
#sudo deluser cathy; sudo rm -rf /home/cathy/
#sudo rm -rf /tmp/ttyd/
#sudo rm /etc/cron.d/cron*
#git reset --hard; git pull

##TODO: create section to check for conflicts to prevent from overwriting existing deployment
## Use previos delete as key


if [[ $1 == "init" ]]
then
    ####### PART ONE: Configuration ##########

    ### Ensure proper Locale ####
    #locale - important for `mdbook build` step
    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8 LANGUAGE=en_US LC_ALL=en_US.UTF-8
    #note: the below statements should help prevent from needing to disconned before continuing
    export LANG=en_US.UTF-8
    export LANGUAGE=en_US
    export LC_ALL=en_US.UTF-8
    ### end ensure proper Locale ####

    ### create local chat user ####
    sudo adduser --disabled-password --gecos "" $CHAT_USER
    echo HERE: make sure $CHAT_USER exists
    ### end create local chat user ####

    #TODO: In next section: instead of copy existing repo, clone from repo based on properties - this way we can use an existing repo

    ### create /opt repositories
    sudo mkdir -p $WI_ROOT_DIR/$GH_PROJECT/
    sudo git clone $WI_URL $WI_ROOT_DIR/$GH_PROJECT/$GH_REPO
    # create properties file:
    for key in "${!SC_VARIABLES[@]}"; do
        echo "$key=\"${SC_VARIABLES[$key]}\"" | sudo tee -a $WI_REPO_DIR/config.properties
    done
    echo HERE: make sure $WI_SRC_DIR exists
    echo HERE: make sure $WI_REPO_DIR/config.properties exists
    ### end create /opt repositories

    ### copy over util directory ####
    sudo cp -r $SC_SCRIPT_DIR/util $WI_REPO_DIR/
    sudo cp $SC_SCRIPT_DIR/publish.sh $WI_REPO_DIR/.
    ### end copy over util directory ####

    ### rename cron
    sudo sed -i "s|WI_REPO_DIR|$WI_REPO_DIR|g" $WI_REPO_DIR/util/cron-file
    sudo mv $WI_REPO_DIR/util/cron-file $WI_REPO_DIR/util/cron-$GH_PROJECT-$GH_REPO
    ### end rename cron

    ### start aichat configure ####
    sudo mkdir -p /home/$CHAT_USER/.config/aichat/roles/
    sudo cp $WI_REPO_DIR/util/$AI_CONFIG /home/$CHAT_USER/.config/aichat/config.yaml
    sudo ln -s $WI_SRC_DIR/$AI_ROLE_STARTER_MD /home/$CHAT_USER/.config/aichat/roles/$AI_ROLE_STARTER_MD
    sudo chown -R $CHAT_USER:$CHAT_USER /home/$CHAT_USER/
    echo run \`sudo -u $CHAT_USER aichat\` and send a test message to confirm all works as expected
    echo run \`sudo -u $CHAT_USER aichat --role $AI_ROLE_STARTER\` and send a test message to confirm the role works as expected
    ### end aichat install ####

    ### create RAG ####
    # create a directory where we can ensure only the files we want ingested are present
    $WI_REPO_DIR/util/stage.sh
    ### end create RAG ####

    ### start ttyd installation ####
    cd /tmp/
    sudo apt-get update
    sudo apt-get install -y build-essential cmake git libjson-c-dev libwebsockets-dev
    git clone https://github.com/tsl0922/ttyd.git
    cd ttyd && mkdir build && cd build
    cmake ..
    make && sudo make install
    ### end ttyd installation ####

    ### start ttyd service ####
    sudo sed -i "s|CHAT_USER|$CHAT_USER|g" $WI_REPO_DIR/util/ttyd.service
    sudo sed -i "s|WI_REPO_DIR|$WI_REPO_DIR|g" $WI_REPO_DIR/util/ttyd.service
    sudo sed -i "s|CHAT_USER|$CHAT_USER|g" $WI_REPO_DIR/util/ai-launcher.sh
    sudo sed -i "s|AI_RAG_ALL|$AI_RAG_ALL|g" $WI_REPO_DIR/util/ai-launcher.sh
    sudo sed -i "s|AI_ROLE_STARTER|$AI_ROLE_STARTER|g" $WI_REPO_DIR/util/ai-launcher.sh
    sudo cp $WI_REPO_DIR/util/ttyd.service $WI_REPO_DIR/util/$WS_SERVICE_NAME.service
    sudo mv $WI_REPO_DIR/util/$WS_SERVICE_NAME.service /etc/systemd/system/$WS_SERVICE_NAME.service
    sudo systemctl daemon-reload
    sudo systemctl enable $WS_SERVICE_NAME.service
    sudo systemctl start $WS_SERVICE_NAME.service
    #sudo journalctl -u $WS_SERVICE_NAME.service #show logs for ttyd
    ### end ttyd service ####

    ### create self-signed cert ###
    #Update the below as you deem appropriate
    country="XX"
    state="XX"
    locality="XX"
    organization="chuck-stack"
    organizationalunit="trainig"
    commonname="XX"
    email="XX"
    
    #Creates a cert that is valid for 10 years
    sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email" \
    -keyout /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt
    ### end  create self-signed cert ###

    ### config of nginx ####
    sudo apt install nginx -y
    echo HERE: WS_SERVICE_NAME=$WS_SERVICE_NAME
    sudo mkdir -p /var/www/$WS_SERVICE_NAME
    sudo cp $WI_REPO_DIR/util/404.html /var/www/.
    sudo chown -R www-data:www-data /var/www/
    sudo chmod -R 755 /var/www/
    sudo sed -i "s|WS_SERVICE_NAME_TTYD|$WS_SERVICE_NAME_TTYD|g" $WI_REPO_DIR/util/nginx-config
    sudo sed -i "s|WS_SERVICE_NAME|$WS_SERVICE_NAME|g" $WI_REPO_DIR/util/nginx-config
    sudo sed -i "s|TTYD_PORT|$TTYD_PORT|g" $WI_REPO_DIR/util/nginx-config
    sudo cp $WI_REPO_DIR/util/nginx-config $WI_REPO_DIR/util/$WS_SERVICE_NAME
    sudo mv $WI_REPO_DIR/util/$WS_SERVICE_NAME /etc/nginx/sites-available/$WS_SERVICE_NAME
    echo cat /etc/nginx/sites-available/$WS_SERVICE_NAME
    sudo ln -s /etc/nginx/sites-available/$WS_SERVICE_NAME /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo systemctl restart nginx
    ### end config of nginx ####
    
    ### update book ####
    sudo sed -i "s|GH_PROJECT|$GH_PROJECT|g" $WI_REPO_DIR/book.toml #used to set github vars
    sudo sed -i "s|GH_REPO|$GH_REPO|g" $WI_REPO_DIR/book.toml #used to set github vars
    sudo sed -i "s|MY_IP|$MY_IP|g" $WI_REPO_DIR/theme/head.hbs
    sudo sed -i "s|WS_SERVICE_NAME_TTYD|$WS_SERVICE_NAME_TTYD|g" $WI_REPO_DIR/theme/head.hbs
    ### end update book ####
    
    ### publish first version ####
    PUBLISH_DATE=`date +%Y%m%d`-`date +%H%M%S`
    echo "**********************"
    echo "***first publish***"
    echo "**********************"
    echo PUBLISH_DATE = $PUBLISH_DATE
    cd $WI_REPO_DIR/
    sudo $WI_REPO_DIR/util/summary.sh
    sudo /usr/local/bin/mdbook build
    sudo rsync -a --delete wi/ /var/www/$WS_SERVICE_NAME/
    sudo chown -R www-data:www-data /var/www/$WS_SERVICE_NAME/
    sudo rm -rf /var/www/$WS_SERVICE_NAME/.obsidian/
    ### end publish first version ####

    ### add tools ####
    sudo git clone https://github.com/sigoden/llm-functions /home/$CHAT_USER/llm-functions
cat << 'EOF' | sudo tee /home/$CHAT_USER/llm-functions/tools/get_env_var.sh
#!/usr/bin/env bash
set -e

# @describe Get environment variables
# @option --envvar! 

# @env LLM_OUTPUT=/dev/stdout The output path

main() {
    echo ${!argc_envvar} >> /tmp/get_env_var.out
    echo ${!argc_envvar} >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
EOF
    sudo chmod +x /home/$CHAT_USER/llm-functions/tools/get_env_var.sh
    echo "get_env_var.sh" | sudo tee -a /home/$CHAT_USER/llm-functions/tools.txt
    sudo chown -R $CHAT_USER:$CHAT_USER /home/$CHAT_USER/llm-functions
    sudo -u $CHAT_USER sh -c "cd /home/$CHAT_USER/llm-functions/ && argc build"
    sudo -u $CHAT_USER sh -c "cd /home/$CHAT_USER/llm-functions/ && argc link-to-aichat"
    ### end add tools ####

    ### Part 1 Summary
    echo
    echo
    echo "*************************"
    echo "***manual instructions***"
    echo "*************************"
    echo
    echo "STEP 1:"
    echo "add your openai and claude keys here: /home/$CHAT_USER/.config/aichat/config.yaml"
    echo " - sudo vim /home/$CHAT_USER/.config/aichat/config.yaml"
    echo
    echo "STEP 2: create your first rag (note: the script will keep this rag updated over time)"
    echo "sudo -u $CHAT_USER aichat"
    echo "> .rag $AI_RAG_ALL"
    echo "> large embedding (default)"
    echo "> 2000 chunk (default)"
    echo "> 100 overlap (default)"
    echo "> $WI_REPO_DIR/rag-stage/**/*.md"
    echo
    echo "STEP 3:"
    echo "go to http://$MY_IP/$WS_SERVICE_NAME/chat.html for documents"
    echo "expand the chat section to see the chat dialog."
    echo "go to http://$MY_IP/$WS_SERVICE_NAME_TTYD/ for dedicated terminal"
    echo
    echo "STEP 4:"
    echo "all scripts are located in $WI_REPO_DIR/"
    echo " - set up a cron job to execute part two on a timer"
    echo " - sudo cp $WI_REPO_DIR/util/cron-$GH_PROJECT-$GH_REPO /etc/cron.d/."
    echo " - This is a git repository owned by root"
    echo " - Update it accordingly"
    echo " - Join the stack-academy if you want help pushing it back so others can see the feedback"
    echo
    echo "STEP 5:"
    echo "consider setting timezone"
    echo " - sudo timedatectl set-timezone America/Chicago"
    echo
    ####### END PART ONE: Configuration ##########
fi

if [[ $1 == "rebuild" ]]
then
    ######## START PART TWO: PUBLISH ##########
    ##NOTE: this section is assumed to be executed as root
    
    PUBLISH_DATE=`date +%Y%m%d`-`date +%H%M%S`
    echo "**********************"
    echo "***starting publish***"
    echo "**********************"
    echo PUBLISH_DATE = $PUBLISH_DATE
    cd $WI_REPO_DIR/ || graceful_exit "cannot cd to $WI_REPO_DIR"
    ##pull latest changes ###change-me### - need to uncomment this section and test
    #git add .
    #git commit -m 'publisher commit summary'
    #git pull --rebase
    util/summary.sh
    /usr/local/bin/mdbook build
    rsync -a --delete wi/ /var/www/$WS_SERVICE_NAME/
    chown -R www-data:www-data /var/www/$WS_SERVICE_NAME/
    rm -rf /var/www/$WS_SERVICE_NAME/.obsidian/
    #systemctl restart ttyd
    #systemctl restart nginx
    
    # Create or clear the output file - prepare to cat all individual chat result directories
    OUTPUT_FILE=/home/$CHAT_USER/.config/aichat/messages.md
    rm -f $OUTPUT_FILE
    
    # Find all individual messages.md files and cat them into the output file
    find /home/$CHAT_USER/.aichat-history/ -name "messages.md" -type f -exec cat {} >> "$OUTPUT_FILE" \;
    chown $CHAT_USER:$CHAT_USER $OUTPUT_FILE
    
    # evaluate combined messages
    sudo -u $CHAT_USER /usr/local/bin/aichat --no-stream -f $WI_SRC_DIR/airole-message-review.md -f $OUTPUT_FILE
    
    # Now that the analysis is complete, rebuild the rag with updated files
    $WI_REPO_DIR/util/stage.sh
    sudo -u $CHAT_USER /usr/local/bin/aichat --rag $AI_RAG_ALL --rebuild-rag
    
    # move messages and evaluation to prompt history so that content creators can evaluate
    mkdir -p $WI_SRC_DIR/prompt-history/
    mv $OUTPUT_FILE $WI_SRC_DIR/prompt-history/messages-$PUBLISH_DATE.md
    
    ##push latest results ###change-me### - need to uncomment this section and test
    #git add .
    #git commit -m 'publisher commit prompt history'
    #git pull --rebase
    #git push
    
    # cleanup history
    rm -rf /home/$CHAT_USER/.aichat-history/*
    
    echo "**********************"
    echo "***ending publish***"
    echo "**********************"
    
    ######## END PART TWO: PUBLISH ##########
fi
