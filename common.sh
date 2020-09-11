#!/bin/bash

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
  sqlite3 $DB_PATH/production_entry.db "select * from production"
}

create_dir_not_present(){
  dir=$1
  if [[ ! -e $dir ]]; then
    mkdir $dir
  else
    echo "$dir already exists"
fi
}

revert_to(){
  local checksum=$1
  echo -e "\n>>>>>Reverting to $checksum >>>>>"
  echo  "Checking checksum with the file"
  # Get the checksum from file
  file_path=$BACKUP_PATH/$checksum".zip"
  echo $file_path
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
  output=$(unzip $BACKUP_PATH/$checksum".zip")
  git stash
  echo -e ">>>>>Revert done>>>>>\n"
}

revert_build(){
  # Enter to the project folder
  read_config; check_for_environment_variable
  get_project_name_from_url
  cd $DEPLOY_PATH
  cd $PROJECT_NAME
  # call revert_to with checksum as argument
  revert_to $1
}

restart_supervisor(){
    echo -e "\n>>>>>=Restarting Server>>>>>="
    sudo supervisorctl restart $PROJECT_NAME
    echo -e ">>>>>=Server Restarted>>>>>==\n"
}

start_nginx(){
    #start the nginx
    sudo /etc/init.d/nginx start
}

restart_nginx(){
    #restart nginx
    sudo /etc/init.d/nginx restart
}

restart_all_server(){
  restart_nginx
  restart_server
}

update_supervisor(){
    echo -e "\n >>> Updating Supervisor >>>"
    sudo supervisorctl reread
    sudo supervisorctl update
}


activate_virtual_environment(){
    echo -e "\n >>> Activating virtual environment >>>"
    source venv/bin/activate
}

enter_to_project_folder(){
    cd $PROJECT_NAME
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