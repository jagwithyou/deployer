#!/bin/bash
source ./common.sh

check_for_message(){
    if [ -z "$MESSAGE" ]
    then
        echo "please provide a message for deployment using message flag (-m)...."
        exit 1
    else
        echo "Message for this deployment is : "$MESSAGE
    fi
}

database_entry () {
new_checksum=$1
# create a table if not present
sqlite3 $DB_PATH/production_entry.db <<'END_SQL'
CREATE TABLE IF NOT EXISTS production(checksum, message);
END_SQL
result=$(sqlite3 ../production_entry.db "insert into production values('$new_checksum', '$MESSAGE')")
}

zip_and_backup(){
  echo -e "\n>>>>> BACKUP Started >>>>>"
    # Zip the project folder
    output=$(zip -r temp.zip ./*)

    #Convert the file name to checksum and move it to backup folder
    new_checksum=$(md5sum temp.zip)
    new_checksum="$(cut -d' ' -f1 <<<"$new_checksum")"
    mv temp.zip $BACKUP_PATH/$new_checksum.zip

    echo "Inserting entry to database"
    echo "Checksum : "$new_checksum
    echo "message : "$MESSAGE
    database_entry $new_checksum
    echo -e ">>>>> BACKUP Done >>>>>\n"
}

clone_project_from_git(){
    echo -e "\n>>>>>Clonning project>>>>>"
    echo "URL : "$URL
    echo "Branch : "$BRANCH
    git checkout $BRANCH
    git pull
    echo -e ">>>>>Clonning done>>>>>\n"
}

run_test(){
    echo -e "\n>>>>>Running Test Cases>>>>>"
    cd test
    output=$(pytest)
    cd ../
    # Check if the tests are passed or not
    SUB=" failed "
    ERROR=" errors "
    INTERNAL_ERROR="INTERNALERROR"
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
    elif [[ "$output" =~ .*"$INTERNAL_ERROR".* ]];
    then
      echo "PFA of report" | mail -s "BUILD Error" jagwithyou@gmail.com -A test/reports/report.html
      echo "It's internal error"
      revert_to $new_checksum
    else
      echo "It's Passed."
      echo "PFA of report" | mail -s "BUILD Success" jagwithyou@gmail.com -A test/reports/report.html
    fi
    echo -e ">>>>>Test Finish>>>>>\n"
}

update(){
    # mkdir ../build_backup
    check_for_message
    read_config; check_for_environment_variable
    echo "Updating..."
    get_project_name_from_url
    echo $PROJECT_NAME
    #Enter into deployed folder
    cd $DEPLOY_PATH
    activate_virtual_environment
    enter_to_project_folder
    create_dir_not_present $BACKUP_PATH
    zip_and_backup; 
    clone_project_from_git
    restart_supervisor
    run_test

}
