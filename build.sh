#!/bin/bash
source ./setup.sh

# Global variable
CONFIG_PATH=deploy.config
TEST=1
usage() {
  cat <<-EOF
  Usage: deploy [options] <env> [command]
  Options:
    -T, --no-tests       ignore test hook
    -C, --config <path>  set config path. defaults to ./deploy.conf
    -m, --message        message for deployment
    -h, --help           output help information
    -c, --checksum       Checksum of the build to revert
  Commands:
    setup                run remote setup commands
    update               update deploy to the latest release
    revert               revert to [n]th last deployment or 1
    list                 list previous deploy commits
EOF
}



check_for_message(){
    if [ -z "$MESSAGE" ]
    then
        echo "please provide a message for deployment using message flag (-m)...."
        exit 1
    else
        echo "Message for this deployment is : "$MESSAGE
    fi
}

check_for_environment_variable(){
    if [ -z "$URL" ]
    then
        echo "please provide a URL for deployment...."
        exit 1
    fi
    if [ -z "$DEPLOY_PORT" ]
    then
        echo "please provide a PORT for deployment...."
        exit 1
    fi
}

read_config(){
    echo "Reading config from "$CONFIG_PATH
    . $CONFIG_PATH
}

get_project_name_from_url(){
    # First spliting by / and then spliting by . to get the project name
    PROJECT_NAME="$(cut -d'/' -f5 <<<"$URL")"
    PROJECT_NAME="$(cut -d'.' -f1 <<<"$PROJECT_NAME")"
}

list_deploys(){
  echo "Checksum|Deployment Message"
  sqlite3 production_entry.db "select * from production"
}

database_entry () {
new_checksum=$1
# create a table if not present
sqlite3 ../production_entry.db <<'END_SQL'
CREATE TABLE IF NOT EXISTS production(checksum, message);
END_SQL
# Add the checksum to the database with message
# sqlite3 production_entry.db select * from production;
result=$(sqlite3 ../production_entry.db "insert into production values('$new_checksum', '$MESSAGE')")
# result=$(sqlite3 ../production_entry.db "select * from production")
# echo $result
}

zip_and_backup(){
  echo -e "\n===== BACKUP Started ====="
    # Zip the project folder
    output=$(zip -r temp.zip ./*)

    #Convert the file name to checksum and move it to backup folder
    new_checksum=$(md5sum temp.zip)
    new_checksum="$(cut -d' ' -f1 <<<"$new_checksum")"
    mv temp.zip ../build_backup/$new_checksum.zip

    echo "Inserting entry to database"
    echo "Checksum : "$new_checksum
    echo "message : "$MESSAGE
    database_entry $new_checksum
    echo -e "===== BACKUP Done =====\n"
}

activate_environment(){
    # Activate the environment
    echo "Activating Environment..."
    source venv/bin/activate
    cd $PROJECT_NAME
}

clone_project_from_git(){
    echo -e "\n=====Clonning project====="
    echo "URL : "$URL
    echo "Branch : "$BRANCH
    git checkout $BRANCH
    git pull
    echo -e "=====Clonning done=====\n"
}

restart_server(){
    echo -e "\n======Restarting Server======"
    sudo supervisorctl restart $PROJECT_NAME
    echo -e "======Server Restarted=======\n"
}

revert_to(){
  local checksum=$1
  echo -e "\n=====Reverting to $checksum ====="
  echo  "Checking checksum with the file"
  # Get the checksum from file
  file_path="../build_backup/"$checksum".zip"
  file_checksum=$(md5sum $file_path)
  file_checksum="$(cut -d' ' -f1 <<<"$file_checksum")"
  # compare the checksum
  if [ "$file_checksum" = "$checksum" ]; then
      echo "Checksum are equal......"
  else
      echo "Checksum is not matching...."
      exit 1
  fi
  echo "Reverting to checksum : "$checksum
  output=$(rm -rfv *)
  echo "Delete done"
  echo $file_path
  output=$(unzip "../build_backup/"$checksum".zip")
  git stash
  echo -e "=====Revert done=====\n"
}

revert_build(){
  # Enter to the project folder
  read_config; check_for_environment_variable
  get_project_name_from_url
  cd $PROJECT_NAME
  # call revert_to with checksum as argument
  revert_to $1
}

run_test(){
    echo -e "\n=====Running Test Cases====="
    cd test
    output=$(pytest)
    cd ../
    # Check if the tests are passed or not
    SUB=" failed "
    ERROR=" errors "
    if [[ "$output" =~ .*"$SUB".* ]]; 
    then
      echo "It's failed."
      echo "PFA of report" | mail -s "BUILD Failed" jagwithyou@gmail.com -A test/reports/report.html
      revert_to $new_checksum
    elif [[ "$output" =~ .*"$ERROR".* ]];
    then
      echo "PFA of report" | mail -s "BUILD Error" jagwithyou@gmail.com -A test/reports/report.html
      echo "It's error"
      revert_to $new_checksum
    else
      echo "It's Passed."
      echo "PFA of report" | mail -s "BUILD Success" jagwithyou@gmail.com -A test/reports/report.html
    fi
    echo -e "=====Test Finish=====\n"
}

create_dir_not_present(){
  dir=$1
  if [[ ! -e $dir ]]; then
    mkdir $dir
  else
    echo "$dir already exists"
fi
}

update(){
    
    # mkdir ../build_backup
    check_for_message
    read_config; check_for_environment_variable
    echo "Updating..."
    get_project_name_from_url
    echo $PROJECT_NAME
    activate_environment
    create_dir_not_present "../build_backup"
    zip_and_backup; 
    clone_project_from_git
    restart_server
    run_test

}

pre_setup(){
  echo -e "\n=====Setup Started====="
  read_config; check_for_environment_variable
  # get_project_name_from_url
  echo "Configurations: "$BRANCH $URL $DEPLOY_PORT
  start_setup $BRANCH $URL $DEPLOY_PORT
  echo -e "=====Setup Finished=====\n"

}



# Define command line argumetns
for i in "$@"
do
case $i in
    -h|--help) usage; exit ;;
    -m=*|--message=*)
    MESSAGE="${i#*=}"
    shift 
    ;;
    -c=*|--checksum=*)
    ARG_CHECKSUM="${i#*=}"
    shift 
    ;;
    -C=*|--config=*)
    CONFIG_PATH="${i#*=}"
    shift 
    ;;
    -T|--no-tests) TEST=0 ;;

    revert) revert_build $ARG_CHECKSUM; exit ;;
    update) update; exit ;;
    setup) pre_setup; exit ;;
    list) list_deploys; exit ;;
   
esac
done





# set_config_path(){
#     CONFIG_PATH=$1
# }

# set_message(){
#     MESSAGE=$1
#     echo $MESSAGE
# }
# # parse argv
# while test $# -ne 0; do
#   arg=$1; shift
#   case $arg in
#     -h|--help) usage; exit ;;
#     -m|--message) set_message $1; shift;;
#     -c|--config) set_config_path $1; shift ;;
#     -T|--no-tests) TEST=0 ;;
#     revert) revert_build ${1-1}; exit ;;
#     setup) require_env; setup $@; exit ;;
#     list) list_deploys; exit ;;
#     update) update; exit ;;
#   esac
# done