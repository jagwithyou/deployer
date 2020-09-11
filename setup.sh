#! /bin/bash





start_setup(){
    BRANCH=$1
    PROJECT_URL=$2
    PORT=$3
    PROJECT_NAME="$(cut -d'/' -f5 <<<"$PROJECT_URL")"
    PROJECT_NAME="$(cut -d'.' -f1 <<<"$PROJECT_NAME")"
    echo $PROJECT_NAME

    # install required libraries
    echo "==========Installing required libraries============="
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-virtualenv nginx git
    sudo apt-get install python3-venv
    # sudo apt-get install postfix mailutils

    #Creating virtual environment
    echo "creating virtual environment and activating it"
    python3 -m venv venv
    source venv/bin/activate

    echo "Clonning the project"
    echo "Branch : "$BRANCH
    echo "Project URL : "$PROJECT_URL
    git clone --single-branch --branch $BRANCH $PROJECT_URL

    #open project folder
    cd $PROJECT_NAME

    #setup application 
    pip3 install -r app/requirements.txt 
    pip3 install -r test/requirements.txt 

    #start the nginx
    sudo /etc/init.d/nginx start

    # #create nginx configuration for the project
    sudo touch /etc/nginx/sites-available/$PROJECT_NAME
    sudo ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/$PROJECT_NAME

    # #edit the file
    # # sudo nano /etc/nginx/sites-enabled/Flask_CICD_Test_App

    string="server {
        location / {
            proxy_pass http://localhost:$PORT;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        location /static {
            alias  /home/www/flask_project/static/;
        }
    }"

    echo $string >> $PROJECT_NAME

    #restart nginx
    sudo /etc/init.d/nginx restart


#     #now run your application and you willsee the website is live
#     /home/jag/sulopa/cicd_test/Flask_CICD_Test_App/venv/bin/gunicorn app:app -b localhost:8007

    #configure supervisor
    sudo apt-get install -y supervisor
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
    echo -e $string >> $filename
    sudo mv $filename "/etc/supervisor/conf.d/"$filename


    #Stop gunicorn:
    sudo pkill gunicorn

    #Start gunicorn with supervisor:

    sudo supervisorctl reread
    sudo supervisorctl update
    # sudo supervisorctl start $PROJECT_NAME

    #now your app will be live
}

# BRANCH="master"
# PROJECT_URL="https://github.com/jagwithyou/Flask_CICD_TEST_1.git"
# PORT=8008
# start_setup $BRANCH $PROJECT_URL $PORT


# var1="Hello"
# var2="World!"
# logwrite="$var1\n$var2"
# echo -e "$logwrite"  >> user.txt