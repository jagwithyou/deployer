#!/bin/bash
source ./setup.sh
source ./update.sh
source ./common.sh

# Global variable
CONFIG_PATH=deploy.config
TEST=1
usage() {
  cat <<-EOF
  Usage: deployer [options] [command]
  Options:
    -T, --no-tests       ignore test hook
    -C, --config <path>  set config path. defaults to ./deploy.config
    -m, --message        message for deployment
    -h, --help           output help information
    -c, --checksum       Checksum of the build to revert
  Commands:
    setup                run remote setup commands
    update               update deploy to the latest release
    revert               revert to [n]th last deployment or 1
    list                 list previous deploy commits
    restart              restart all (Nginx, Supervisor)
    restartsupervisor    restart Supervisor
    restartnginx         restart Nginx
    delete               delete the project setup
EOF
}


get_project_details(){
  read_config; 
  get_project_name_from_url;
}


# Define command line argumetns
for i in "$@"
do
case $i in
    # Options
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
    # Commands
    revert) revert_build $ARG_CHECKSUM; exit ;;
    update) update; exit ;;
    setup) pre_setup; exit ;;
    list) get_project_details; list_deploys; exit ;;
    restart) get_project_details; restart_all_server; exit ;;
    restartsupervisor) get_project_details; restart_supervisor; exit ;;
    restartnginx) restart_nginx; exit ;;
    delete) get_project_details; delete_project; exit ;;

esac
done