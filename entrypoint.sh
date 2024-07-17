#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Global flags for interrupt handling and cleanup status
export INTERRUPT_RECEIVED=0
export CLEANUP_IN_PROGRESS=0

# SSH connection details
SSH_HOST="localhost"
SSH_USER="quickemu"
SSH_PORT=22220

# Keep alive configuration (defaults to true if not set)
KEEP_ALIVE=${KEEP_ALIVE:-true}

# Function to clean up processes and perform shutdown
cleanup() {
    # Prevent multiple cleanup processes from running simultaneously
    if ((CLEANUP_IN_PROGRESS == 1)); then
        return
    fi
    CLEANUP_IN_PROGRESS=1

    sleep 1
    
    reset_output

    echo -e "\nCleaning up..."

    shutdown_vm

    # Terminate all child processes of this script
    pkill -P $$ || true
    
    # Exit with appropriate status based on whether an interrupt was received
    if ((INTERRUPT_RECEIVED == 1)); then
        exit 1
    else
        exit 0
    fi
}

# Function to reset terminal output for clean display
reset_output() {
    # Exit if not running in a terminal
    if [ ! -t 1 ]; then
        return
    fi

    # Reset terminal settings
    stty sane 2>/dev/null || true

    # Clear current line and reset text attributes
    tput el sgr0 2>/dev/null || true

    # Fallback to ANSI escape codes if tput fails
    if [ $? -ne 0 ]; then
        printf '\033[2K\r\033[0m'
    fi

    # Flush input buffer
    while read -r -t 0.01; do : ; done
}

# Function to shut down the VM
shutdown_vm() {
    # Check if the Windows VM is running
    if ! pgrep -x "windows-11" >/dev/null; then
        echo "Windows VM is not running. Skipping shutdown."
        return
    fi

    echo "Shutting down Windows VM..."
    # Attempt to send shutdown command to Windows
    if ssh $SSH_USER@$SSH_HOST -p $SSH_PORT 'shutdown /s /t 0' &> /dev/null; then
        echo "Shutdown command sent successfully."
        
        wait_for_vm_shutdown() {
            ./wait-for-process.sh windows-11 120 &> /dev/null
        }

        # Wait for VM to shut down, showing a spinner
        if show_spinner "Waiting for Windows VM to shut down..." wait_for_vm_shutdown; then
            echo "Windows VM has shut down successfully."
        else
            echo "Error: Timeout waiting for Windows VM to shut down. The VM will be forcefully terminated."
        fi
    else
        echo "Failed to send shutdown command (perhaps it hasn't fully booted?). The VM will be forcefully terminated."
    fi
}

# Function to display a spinner while a process is running
spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'
    
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r%s %c" "$message" "${spinstr:0:1}"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r%s    \n" "$message"
}

# Function to show spinner with message while executing a given function
show_spinner() {
    local message="$1"
    local func="$2"
    shift 2
    local funcargs=("$@")
    
    "${func}" "${funcargs[@]}" &
    local pid=$!
    spinner $pid "$message"
    
    wait $pid
    return $?
}

# Function to start VM
start_vm() {
    ./launch-quickemu.sh &> /dev/null
}

# Function to wait for Windows to be online
wait_for_windows() {
    local timeout=120
    local elapsed=0

    wait_for_ssh() {
        while (( elapsed < timeout )); do
            if ./poll-ssh.sh -a 1 -d 1 &> /dev/null; then
                return 0
            fi
            sleep 1
            ((elapsed++))
        done
        return 1
    }

    if show_spinner "Waiting for Windows to be online..." wait_for_ssh; then
        echo "Windows is online!"
        return 0
    else
        echo "Error: Failed to establish a connection to Windows VM within the timeout period."
        return 1
    fi
}

# Function to connect via SSH, handling both interactive and non-interactive modes
ssh_connect() {
    local cmd="$*"
    local ssh_opts="-q -p $SSH_PORT $SSH_USER@$SSH_HOST"

    if [[ ${INTERACTIVE,,} == true ]]; then
        ssh_opts="-t $ssh_opts"
        if [[ -z "$cmd" ]]; then
            echo "No command specified. Connecting to SSH host..."
            ssh $ssh_opts
        else
            echo "Executing command on SSH host and maintaining interactive session"
            ssh $ssh_opts "$cmd && cmd"
        fi
    elif [[ -n "$cmd" ]]; then
        echo "Executing command on SSH host"
        ssh $ssh_opts "$cmd"
    else
        echo "No command specified. Skipping."
    fi
}

# Function to keep the container running if KEEP_ALIVE is set
keep_alive() {
    if [[ ${KEEP_ALIVE,,} == "true" ]]; then
        echo "Persisting container..."
        while true; do
            sleep 1
        done
    fi
}

# Function to start signal monitor for handling interrupts
start_signal_monitor() {
    trap 'handle_interrupt' SIGINT SIGTERM SIGHUP SIGQUIT
    
    handle_interrupt() {
        INTERRUPT_RECEIVED=1
        pkill ssh || true
        kill -SIGUSR1 $$
    }
    
    while true; do
        sleep 1
    done
}

# Start the signal monitor in the background
start_signal_monitor &
MONITOR_PID=$!

# Handle script completion and interrupts in the main process
trap 'cleanup' EXIT SIGUSR1

# Main function to orchestrate the script's operations
main() {
    # Determine if running in interactive mode
    if [[ -t 0 && -t 1 ]]; then
        INTERACTIVE=true
    else
        INTERACTIVE=false
    fi

    # Verify KVM availability
    if ! kvm-ok &> /dev/null; then
        echo "Error: KVM acceleration is not available."
        echo "Did you pass --device=/dev/kvm and is it accessible on the host?"
        exit 1
    fi

    # Start VM with visual feedback
    if ! show_spinner "Starting VM..." start_vm; then
        echo "Error: Failed to start the VM."
        exit 1
    fi

    # Ensure Windows is online before proceeding
    if ! wait_for_windows; then
        exit 1
    fi

    # Handle SSH connection or command execution, filtering out connection closed messages
    ssh_connect "$@" 2> >(grep -vE "Connection to .* closed by remote host\." >&2)

    # Keep the container running if necessary
    if [[ ${INTERACTIVE,,} == "false" ]] || [[ ${KEEP_ALIVE,,} == "true" ]]; then
        keep_alive
    fi
}

# Execute the main function with all script arguments
main "$@"