#!/bin/bash

# The SSH options to use for the connection
SSH_OPTIONS="-o ControlMaster=auto -o ControlPersist=600 -o ControlPath=~/.ssh/control:%h:%p"

# The command to run on the remote machine
REMOTE_COMMAND="ls"
#REMOTE_COMMAND="counter=0; while [ \$counter -lt 10 ]; do echo \"Counter is: \$counter\"; ((counter++)); done"


# The SSH connection string
SSH_CONNECTION="cbaq@172.28.235.114"

# Start the SSH connection in the background
ssh $SSH_OPTIONS -N $SSH_CONNECTION &

SSH_PID=$(ps aux | grep "ssh -o " | awk '{print $2}' | head -n 1)

# Loop 10 times
for i in {1..10}
do
    # Run the command on the remote machine
    ssh $SSH_OPTIONS $SSH_CONNECTION "$REMOTE_COMMAND"

    # Wait for 1 second
    sleep 1

    # store ssh pid

done

# Terminate the SSH connection
kill $SSH_PID
echo "killed $SSH_PID"
