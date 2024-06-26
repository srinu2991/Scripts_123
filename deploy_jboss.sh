#!/bin/bash

#set -x
LOG_FILE="jboss-deploy.log"

# Check if the log file exists
if [ -f "$LOG_FILE" ]; then
    # Create a backup with the current date
    BACKUP_FILE="$LOG_FILE.$(date +'%Y%m%d%H%M%S')"
    mv "$LOG_FILE" "$BACKUP_FILE"
fi

# Redirect output to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to calculate the MD5 hash of a file
function calculate_md5() {
    md5sum "$1" | awk '{print $1}'
}

# Function to stop server group
function stop_server_group() {
    if [ -z "$SERVER_GROUP" ]; then
        echo "Error: Server group not provided."
        exit 1
    fi
    echo "***************************"
    echo "Stop server group..."
    echo "***************************"
    "$ENV_HOME"/"$environment_name"/bin/jboss-cli.sh --connect controller="$CONTROLLER_HOST":"$CONTROLLER_PORT" --user="$JBOSS_USER" --password="$JBOSS_PASSWORD" --command="/server-group=$SERVER_GROUP:stop-servers"
    sleep 1m

    # Call the function to check and kill JVMs on master and slave servers
    check_and_kill_jvms_on_servers
}

# Function to check if server group JVMs are down and kill any running JVMs on master and slave servers
function check_and_kill_jvms_on_servers() {
    echo "**********************************"
    echo "Checking if server group JVMs are down on master server..."
    echo "**********************************"
    # Use ps and grep to check for the JVM processes on the master server
    jvm_status_master=$(pgrep -f "$environment_name" | xargs ps -o pid= -o args= | awk '/-D\[Server:/ {gsub(/^-D\[Server:/, ""); gsub(/\].*$/, ""); print $1, $6}')

    # Print the output (PID and JVM name) on the master server
    echo "$jvm_status_master"

    # Extract PID from the output on the master server (assuming PID is the first column)
    pid_master=$(echo "$jvm_status_master" | awk '{print $1}')

    # Kill the process on the master server
    if [ -n "$pid_master" ]; then
        echo "Killing process with PID: $pid_master on the master server"
        kill -9 "$pid_master"
    else
        echo "No matching process found on the master server."
    fi

    # Loop through each slave server and check and kill JVMs
    IFS=',' read -ra SERVERS <<<"$SERVERS_LIST"
    for server in "${SERVERS[@]}"; do
        echo "**********************************"
        echo "Checking if server group JVMs are down on slave server $server..."
        echo "**********************************"

        # Use ssh to execute the check and kill process on the slave server
        ssh "$SSH_USER@$server" "$\(declare -f check_and_kill_jvms); check_and_kill_jvms"

        echo "**********************************"
        echo "Finished checking on slave server $server."
        echo "**********************************"
    done
}

# Function to undeploy EAR
function undeploy_ear() {
    if [ -z "$EAR_NAME" ]; then
        echo "Error: EAR name not provided."
        exit 1
    fi
    echo "***************************"
    echo "Undeploying EAR: $EAR_NAME"
    echo "***************************"

    if ! "$ENV_HOME"/"$environment_name"/bin/jboss-cli.sh --connect controller="$CONTROLLER_HOST":"$CONTROLLER_PORT" --user="$JBOSS_USER" --password="$JBOSS_PASSWORD" --command="undeploy $EAR_NAME --server-groups=$SERVER_GROUP"; then
        echo "Undeploy command failed"
        exit 1
    else
        echo "Undeploy command executed sucessfully"
    fi
}

# Function to check if EAR is undeployed
function check_ear_undeployed() {
    if [ -z "$EAR_NAME" ]; then
        echo "Error: EAR name not provided."
        exit 1
    fi

    undeploy_status=$("$ENV_HOME"/"$environment_name"/bin/jboss-cli.sh --connect controller="$CONTROLLER_HOST":"$CONTROLLER_PORT" --user="$JBOSS_USER" --password="$JBOSS_PASSWORD" --command="deployment-info --server-group=$SERVER_GROUP")

    # Print the output
    echo "$undeploy_status"

    # Check if EAR_NAME exists in the output
    if echo "$undeploy_status" | grep -q "$EAR_NAME"; then
        echo "$EAR_NAME exists in the output. Script failed."
        exit 1
    else
        echo "**********************************"
        echo "$EAR_NAME not found in the output."
        echo "**********************************"
    fi
}

# Function to clean up folders on master and slave servers
function clean_up_folders() {
    echo "****************************************"
    echo "Cleaning up folders... in Master Server"
    echo "****************************************"
    rm -rf "$ENV_HOME/$environment_name/domain/servers/*/data/content/*"
    rm -rf "$ENV_HOME/$environment_name/domain/servers/*/tmp/*"
    rm -rf "$ENV_HOME/$environment_name/domain/servers/*/data/infinispan/*"
    rm -rf "$ENV_HOME/$environment_name/domain/servers/*/data/wsdl/*"

    if [ -z "$SERVERS_LIST" ]; then
        echo "Error: Servers list not provided."
        exit 1
    fi
    # Create a cleanup script
    cleanup_script=$(mktemp)
    cat <<EOSCRIPT >"$cleanup_script"
#!/bin/bash
for dir in "$ENV_HOME/$environment_name"/servers/*; do
    rm -rf "\$dir/data/content"/*
    rm -rf "\$dir/tmp"/*
    rm -rf "\$dir/data/infinispan"/*
    rm -rf "\$dir/data/wsdl"/*
done
EOSCRIPT
    # Set execution permissions for the cleanup script
    chmod +x "$cleanup_script"
    echo "****************************************"
    echo "Cleaning up folders... in slave servers"
    echo "****************************************"
    IFS=',' read -ra SERVERS <<<"$SERVERS_LIST"
    for server in "${SERVERS[@]}"; do
        scp "$cleanup_script" "$SSH_USER@$server:~/cleanup_script.sh"
        ssh "$SSH_USER@$server" "chmod +x ~/cleanup_script.sh; bash ~/cleanup_script.sh"
        ssh "$SSH_USER@$server" "rm -f ~/cleanup_script.sh"
    done

    # Clean up the temporary cleanup script
    rm -f "$cleanup_script"
}

# Function to copy properties jar to master and slave servers
function copy_properties_jar() {
    if [ -z "$SERVERS_LIST" ]; then
        echo "Error: Servers list or properties jar paths not provided."
        exit 1
    fi
    echo "**************************************"
    echo "Unzip EAR and provide the permissons"
    echo "**************************************"
    unzip -o "$SCRIPT_PATH"/"$environment_name"/online.zip -d "$SCRIPT_PATH"/"$environment_name"/online
    chmod -R 775 "$SCRIPT_PATH"/"$environment_name"/online

    echo "******************************************"
    echo "Copying properties jar into Master Server"
    echo "******************************************"

    if [[ "$environment_name" == "CCWPUAT1" ]]; then
        cp "$SCRIPT_PATH"/"$environment_name"/online/properties/enh_uat-properties.jar "$ENV_HOME"/"$environment_name"/modules/ieapp/sharedlib/main/properties.jar
    elif [[ "$environment_name" == "EAP7.4_UAT" ]]; then
        cp "$SCRIPT_PATH"/"$environment_name"/online/properties/uat1-properties.jar "$ENV_HOME"/"$environment_name"/modules/ieapp/sharedlib/main/properties.jar
    elif [[ "$environment_name" == "EAP7.4_UAT_TT" ]]; then
        cp "$SCRIPT_PATH"/"$environment_name"/online/properties/uat3-properties.jar "$ENV_HOME"/"$environment_name"/modules/ieapp/sharedlib/main/properties.jar
    elif [[ "$environment_name" == "EAP7.4_PERF" ]]; then
        cp "$SCRIPT_PATH"/"$environment_name"/online/properties/perf-properties.jar "$ENV_HOME"/"$environment_name"/modules/ieapp/sharedlib/main/properties.jar
    elif [[ "$environment_name" == "EAP7.4_PROD" ]]; then
        cp "$SCRIPT_PATH"/"$environment_name"/online/properties/prod-properties.jar "$ENV_HOME"/"$environment_name"/modules/ieapp/sharedlib/main/properties.jar
    else
        echo "Invalid environment_name specified."
        exit 1
    fi
    echo "*******************************************"
    echo "Copying properties jar into Slave Servers"
    echo "*******************************************"

    IFS=',' read -ra SERVERS <<<"$SERVERS_LIST"
    for server in "${SERVERS[@]}"; do
        if [[ "$environment_name" == "CCWPUAT1" ]]; then
            scp "$SCRIPT_PATH"/"$environment_name"/online/properties/enh_uat-properties.jar "$server":"$ENV_HOME"/"$environment_name"/modules/ieapp/sharedlib/main/properties.jar
        elif [[ "$environment_name" == "EAP7.4_UAT" ]]; then
            scp "$SCRIPT_PATH"/"$environment_name"/online/properties/uat1-properties.jar "$server":"$ENV_HOME"/"$environment_name"/modules/ieapp/sharedlib/main/properties.jar
        elif [[ "$environment_name" == "EAP7.4_UAT_TT" ]]; then
            scp "$SCRIPT_PATH"/"$environment_name"/online/properties/uat3-properties.jar "$server":"$ENV_HOME"/"$environment_name"/modules/ieapp/sharedlib/main/properties.jar
        elif [[ "$environment_name" == "EAP7.4_PERF" ]]; then
            scp "$SCRIPT_PATH"/"$environment_name"/online/properties/perf-properties.jar "$server":"$ENV_HOME"/"$environment_name"/modules/ieapp/sharedlib/main/properties.jar
        elif [[ "$environment_name" == "EAP7.4_PROD" ]]; then
            scp "$SCRIPT_PATH"/"$environment_name"/online/properties/prod-properties.jar "$server":"$ENV_HOME"/"$environment_name"/modules/ieapp/sharedlib/main/properties.jar
        else
            echo "Invalid environment_name specified."
            exit 1
        fi
    done
}

# Function to compare EAR between two folders
function compare_ear_folders() {
    if [ -z "$EAR_NAME" ]; then
        echo "Error: EAR name not provided."
        exit 1
    fi
    # Calculate the MD5 hashes of the EAR files
    md5_old_ear_file=$(calculate_md5 "$SCRIPT_PATH"/"$environment_name"_*/online/"$EAR_NAME".ear)
    md5_new_ear_file=$(calculate_md5 "$SCRIPT_PATH"/"$environment_name"/online/"$EAR_NAME".ear)

    # Compare the MD5 hashes
    if [ "$md5_old_ear_file" = "$md5_new_ear_file" ]; then
        echo "The EAR files are matched"
        exit 1 # Exiting with ERR status
    else
        echo "***********************************************************"
        echo "The EAR files do not match proceeding with another steps."
        echo "***********************************************************"
    fi
}

# Function to deploy EAR
function deploy_ear() {
    if [ -z "$EAR_NAME" ] || [ -z "$SERVER_GROUP" ]; then
        echo "Error: EAR name or server group not provided."
        exit 1
    fi
    echo "***************************"
    echo "Deploying EAR: $EAR_NAME"
    echo "***************************"

    "$ENV_HOME"/"$environment_name"/bin/jboss-cli.sh --user="$JBOSS_USER" --password="$JBOSS_PASSWORD" --connect controller="$CONTROLLER_HOST":"$CONTROLLER_PORT" --commands="deploy ""$SCRIPT_PATH""/""$environment_name""/online/$EAR_NAME.ear --name=$EAR_NAME --runtime-name=$EAR_NAME.ear --server-groups=$SERVER_GROUP"
}

# Function to check deployment status
function check_deployment_status() {
    if [ -z "$EAR_NAME" ]; then
        echo "Error: EAR name not provided."
        exit 1
    fi
    echo "**************************************"
    echo "Checking deployment status: $EAR_NAME"
    echo "**************************************"
    output=$("$ENV_HOME"/"$environment_name"/bin/jboss-cli.sh --connect controller="$CONTROLLER_HOST":"$CONTROLLER_PORT" --user="$JBOSS_USER" --password="$JBOSS_PASSWORD" --command="/server-group=$SERVER_GROUP/deployment=$EAR_NAME:read-resource()")
    #print deployment status
    echo "$output"
    #check EAR deployment status
    if [[ $output == *'"outcome" => "success"'* ]]; then
        echo "***************************"
        echo "EAR Deployed successfully"
        echo "***************************"
    else
        echo "Outcome: Failed"
        exit 1
    fi
}

# Function to check if a key is present in a log file
function check_log_for_key() {
    local log_file="$1"
    local search_key="$2"

    if grep -q "$search_key" "$log_file"; then
        echo "***************************"
        echo "Key found in $log_file"
        echo "***************************"
    else
        echo "Key not found in $log_file"
        exit 1
    fi
}

# Function to start server group and validate deployment in server.log files
function start_server_group_and_validate() {
    if [ -z "$SERVER_GROUP" ]; then
        echo "Error: Server group not provided."
        exit 1
    fi
    echo "*******************************"
    echo "Starting slave server group..."
    echo "*******************************"
    "$ENV_HOME"/"$environment_name"/bin/jboss-cli.sh --connect controller="$CONTROLLER_HOST":"$CONTROLLER_PORT" --user="$JBOSS_USER" --password="$JBOSS_PASSWORD" --command="/server-group=$SERVER_GROUP:start-servers"

    sleep 5m

    # Validate deployment in server.log files on master and slave servers

    # Check log files on the master server
    for server_dir in "$ENV_HOME/$environment_name"/domain/servers/*/log/; do
        # Get the latest server.log file in each folder on the master server
        log_file=$(find "$server_dir" -type f -name "server.log" -printf "%T@ %p\n" | sort -nr | head -n 1 | cut -d ' ' -f 2)

        # Check if the log file exists and has the key on the master server
        if [ -f "$log_file" ]; then
            check_log_for_key "$log_file" "WFLYSRV0010: Deployed \"$EAR_NAME\""
        else
            echo "Log file not found in $server_dir on the master server"
            exit 1
        fi
    done

    # Loop through each slave server and check log files
    IFS=',' read -ra servers <<<"$SERVERS_LIST"
    for server in "${servers[@]}"; do
        # Run commands on the remote server without a pseudo-terminal
        ssh -T "$SSH_USER@$server" <<EOF
        for server_dir in "$ENV_HOME/$environment_name"/domain/servers/*/log/; do
            # Get the latest server.log file in each folder on the slave server
            log_file=\$(find "\$server_dir" -type f -name "server.log" -printf "%T@ %p\n" | sort -nr | head -n 1 | cut -d ' ' -f 2)

            # Check if the log file exists and has the key on the slave server
            if [ -f "\$log_file" ]; then
                if grep -q "WFLYSRV0010: Deployed \"$EAR_NAME\"" "\$log_file"; then
                    echo "Key found in \$log_file on $server"
                else
                    echo "Key not found in \$log_file on $server"
                    exit 1
                fi
            else
                echo "Log file not found in \$server_dir on $server"
                exit 1
            fi
        done
EOF

        # Check the exit status of the remote script
        if [ $? -ne 0 ]; then
            echo "Script failed on $server"
            exit 1
        fi
    done
    echo "*********************************************************************"
    echo "All log files contain the key: 'WFLYSRV0010: Deployed \"$EAR_NAME\"'"
    echo "*********************************************************************"
    exit 0
}

# Function to display usage information
function display_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -u, --undeploy           Undeploy EAR"
    echo "  -k, --undeploystatus     check undeployment status"
    echo "  -s, --stop               Stop server group and check status"
    echo "  -c, --cleanup            Clean up folders on master and slave servers"
    echo "  -l, --copy               Copy properties jar to master and slave servers"
    echo "  -d, --compare            Compare EAR between two folders"
    echo "  -v, --deploy             Deploy EAR and check deployment status"
    echo "  -y, --deploystatus       check deployment status"
    echo "  -g, --validate           Start server group and validate deployment"
    echo "  -h, --help               Display this help and exit"
}

# Function to handle errors with the trap command
function handle_error() {
    local exit_code="$?"
    echo "Script encountered an error with exit code $exit_code"
    exit 1
}

# Function to source the config file
function source_config_file() {
    if [ -z "$1" ]; then
        echo "Error: Environment name not provided."
        exit 1
    fi

    local config_file="config_${1}.sh"

    if [ -f "$config_file" ]; then
        # shellcheck source=src/config.sh
        source "./$config_file"

        echo "*****************"
        echo "Print Variables"
        echo "*****************"
        echo "Environment name = $environment_name"
        echo "Server Group = $SERVER_GROUP"
        echo "EAR NAME = $EAR_NAME"
        echo "USER = $SSH_USER"
        echo "SERVER LIST = $SERVERS_LIST"
        echo "JBOSS_HOME = $ENV_HOME"
        echo "EAR LOCATION = $SCRIPT_PATH"
        echo "*****************************"
    else
        echo "Error: Configuration file for environment '$1' not found."
        exit 1
    fi
}

# Function to execute all options
function execute_all_options() {
    stop_server_group
    undeploy_ear
    check_ear_undeployed
    clean_up_folders
    copy_properties_jar
    compare_ear_folders
    deploy_ear
    check_deployment_status
    start_server_group_and_validate
}

# Process command-line options and arguments
if [ $# -eq 0 ]; then
    display_usage
    exit 1
fi

execute_all_flag=false

while [[ $# -gt 0 ]]; do
    case "$1" in
    -e)
        if [ -z "$2" ]; then
            echo "Error: Environment name not provided with -e option."
            exit 1
        fi
        environment_name="$2"
        source_config_file "$2"
        shift # Move to the next argument after -e
        ;;
    -p)
        if [ -z "$2" ]; then
            echo "Error: Password not provided with -p option."
            exit 1
        fi
        JBOSS_PASSWORD="$2"
        shift # Move to the next argument after -p
        ;;
    -s) stop_server_group ;;
    -u) undeploy_ear ;;
    -k) check_ear_undeployed ;;
    -c) clean_up_folders ;;
    -l) copy_properties_jar ;;
    -d) compare_ear_folders ;;
    -v) deploy_ear ;;
    -y) check_deployment_status ;;
    -g) start_server_group_and_validate ;;
    -h)
        display_usage
        exit 0
        ;;
    -a) execute_all_flag=true ;;
    *)
        echo "Invalid option: $1"
        display_usage
        exit 1
        ;;
    esac
    shift # Move to the next argument
done

# Execute all options if -a flag is set
if [ "$execute_all_flag" = "true" ]; then
    execute_all_options
fi
