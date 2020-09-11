#! /bin/bash
source ./common.sh

install_required_linux_packages(){
    echo -e "\n >>> Installing required linux libraries >>>"
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-virtualenv nginx git
    sudo apt-get install python3-venv
    sudo apt-get install -y supervisor
}

create_virtual_environment(){
    echo -e "\n >>> creating virtual environment >>>"
    python3 -m venv venv
}

install_required_python_libraries(){
    echo -e "\n >>> Installing required python libraries >>>"
    pip3 install -r app/requirements.txt 
    pip3 install -r test/requirements.txt
}
clone_repository(){
    echo -e "\n >>> Clonning the project >>>"
    echo "Branch : "$BRANCH
    echo "Project URL : "$PROJECT_URL
    git clone --single-branch --branch $BRANCH $PROJECT_URL
}

setup_nginx_configuration(){
    echo -e "\n >>> Configuring for nginx >>>"
    nginx_setup_string="server { \n
        location / { \n
            proxy_pass http://localhost:$PORT; \n
            proxy_set_header Host \$host; \n
            proxy_set_header X-Real-IP \$remote_addr; \n
        } \n
        location /static { \n
            alias  /home/www/flask_project/static/; \n
        } \n
    }"

    # echo $string >> $PROJECT_NAME
    filename=$PROJECT_NAME
    rm -f $filename
    echo -e $nginx_setup_string >> $filename
    echo "Removing current files from nginx"
    sudo rm -f "/etc/nginx/sites-available/"$filename
    sudo rm -f /etc/nginx/sites-enabled/$PROJECT_NAME
    sudo cp $filename "/etc/nginx/sites-available/"$filename
    sudo ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/$PROJECT_NAME
}

setup_supervisor_configuration(){
    echo -e "\n >>> Configuring for supervisor >>>"
    #configure supervisor
    ## sudo nano /etc/supervisor/conf.d/Flask_CICD_Test_App.conf

    working_directory=$(pwd)
    echo "Work dir" $working_directory

    program="[program:$PROJECT_NAME]"
    command="command = $working_directory/../venv/bin/gunicorn app:app -b localhost:$PORT"
    directory="directory = $working_directory/app"
    user="user = jag"
    autostart="autostart=true"
    err="stderr_logfile=/var/log/supervisor/test.err.log"
    out="stdout_logfile=/var/log/supervisor/test.out.log"
    
    string="$program\n$command\n$directory\n$user\n$autostart\n$err\n$out"

    filename=$PROJECT_NAME".conf"
    sudo rm -f $filename
    echo -e $string >> $filename
    sudo rm -f "/etc/supervisor/conf.d/"$filename
    sudo mv $filename "/etc/supervisor/conf.d/"$filename
}

stop_gunicorn(){
    #Stop gunicorn:
    sudo pkill gunicorn
}

start_setup(){
    PROJECT_URL=$URL
    PORT=$DEPLOY_PORT
    PROJECT_NAME="$(cut -d'/' -f5 <<<"$PROJECT_URL")"
    PROJECT_NAME="$(cut -d'.' -f1 <<<"$PROJECT_NAME")"
    echo "Project Name : " $PROJECT_NAME

    install_required_linux_packages
    clone_repository
    create_virtual_environment
    activate_virtual_environment
    enter_to_project_folder
    install_required_python_libraries
    setup_nginx_configuration
    start_nginx
    restart_nginx
    setup_supervisor_configuration
    stop_gunicorn
    update_supervisor
}


pre_setup(){
  echo -e "\n>>> Setup Started >>>"
  read_config; check_for_environment_variable
  echo "Creating and opening $DEPLOY_PATH"
  create_dir_not_present $DEPLOY_PATH
  cd $DEPLOY_PATH
  start_setup
  echo -e ">>> Setup Finished >>>\n"

}