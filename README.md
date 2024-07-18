# Notes

This is a pre-built Windows 11 Docker image. Unlike other implementations of Windows-in-Docker, the installation is part of the build process. Simply pull the image and you have a ready-to-use Windows container.

It's made possible by the excellent [Quickemu](https://github.com/quickemu-project/quickemu) project.

# Run

Tested and working in WSL-2 (i.e. Windows Host => WSL-2 => Docker => [ QEMU => Win-11 ] ).

Usage:

`docker run --rm -it -p 5900:5900 --device=/dev/kvm --stop-timeout 120 sebbodger/win-docker:latest`

> **Note:** You must pass the `/dev/kvm` device flag in order for QEMU to use virtualization on the host

Once Windows is ready, this will automatically initiate an interactive SSH session (see the Behaviour section for a full explanation). VNC will be available on the host at 5900.   

The image also supports:

- RDP: Port 3389
- VNC: Port 5900
- Spice: Port 9843
- SSH: Port 22220
- File Share (see below)

If you need a directory to be accessible within the Windows image, just mount it to `/root/win-docker/samba/`. For example:

`docker run --rm -it ... -v /host/directory:/root/win-docker/samba sebbodger/win-docker:latest`

On Windows, this will be accessible at `\\10.0.2.4\qemu\` and, for convenience, this is premapped as a (persisted) network drive on `H:`

> **Note:** In SSH, you won't have access to `H:` due to the double-hop problem.  Instead use the UNC path directly i.e. `\\10.0.2.4\qemu\`. Refer to the Example section for running a custom script that is mounted with Docker.

# Examples

## 1.

Start the container, run a simple command once Windows is ready, and then gracefully shutdown:

```bash
docker run --rm \
    -p 5900:5900 \
    --device=/dev/kvm \
    --stop-timeout 120 \
    sebbodger/win-docker:latest \
    "echo Hello from Windows!"
```
Ouput:

```
Starting VM...    
Waiting for Windows to be online...    
Windows is online!
Executing command on SSH host
Hello from Windows!

Cleaning up...
Shutting down Windows VM...
Waiting for Windows VM to shut down...    
Windows VM has shut down successfully.
```

## 2.

Start the container, run a Powershell script (named `PythonScript.ps1`) that installs Python via Chocolately, then run a sample .py script and, finally, gracefully shut down:

```powershell
# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Import Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# Refresh environment variables
refreshenv

# Install Python using Chocolatey
choco install python -y

# Refresh environment variables again
refreshenv

# Create a simple Python script
$pythonScript = @"
import sys
print(f"Hello from Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")
"@

# Save the Python script to a file
$pythonScript | Out-File -FilePath ".\hello_python.py" -Encoding utf8

# Run the Python script
python .\hello_python.py

# Clean up: remove the temporary Python script file
Remove-Item .\hello_python.py
```


```bash
docker run --rm \
    -p 5900:5900 \
    --device=/dev/kvm \
    --stop-timeout 120 \
    -v /host/directory/PythonScript.ps1:/root/win-docker/samba/PythonScript.ps1 \
    sebbodger/win-docker:latest \
    'powershell -ExecutionPolicy Bypass -File "\\10.0.2.4\qemu\PythonScript.ps1"'
```
Ouput:

```
Starting VM...    
Waiting for Windows to be online...    
Windows is online!
Executing command on SSH host

....

 - KB3035131 v1.0.3
 - python v3.12.4
 - python3 v3.12.4
 - python312 v3.12.4
 - vcredist140 v14.40.33810
 - vcredist2015 v14.0.24215.20170201
Refreshing environment variables from the registry for powershell.exe. Please wait...
Finished
Hello from Python 3.12.4

Cleaning up...
Shutting down Windows VM...
Waiting for Windows VM to shut down...    
Windows VM has shut down successfully.
```

# Behaviour

By default, the `entrypoint.sh` detects whether you have requested interactive mode (`-it`) and switches behaviour depending on if you have also provided a command argument - or not. This is best summarised as follows:

| Interactive Mode | Command Argument | Behaviour |
|------------------|-------------------|----------|
| True | Provided | 1. Connects to SSH host with `-t` option for interactive session.<br>2. Executes the provided command.<br>3. Maintains an interactive session by running `cmd` after the command execution. |
| True | Not Provided | 1. Connects to SSH host with `-t` option for interactive session.<br>2. Opens an interactive SSH session without executing any specific command. |
| False | Provided | 1. Connects to SSH host without `-t` option (non-interactive).<br>2. Executes the provided command.<br>3. Exits after command execution. |
| False | Not Provided | 1. Skips SSH connection.<br>2. Prints "No command specified. Skipping." |

For example, `docker run -it ... sebbodger/win-docker:latest` will launch into an interactive SSH session.

Whereas, in non-interactive mode, `docker run ... sebbodger/win-docker:latest "echo Hello from Windows!"` will run the command and then exit.

In both cases, the container will respond to `docker stop` by trapping the interrupt signal and then attempt to gracefully shutdown the Windows VM (even if you are in interactive SSH session at the time).

> **Note:** If you don't like the default behaviour and want to fully customise it for your own use-case, just override the entrypoint: `docker run -it ... --entrypoint /bin/bash`.  You are responsible for starting the VM etc.

# Build

For convenience, this repository is configured with a devcontainer specification . Docker-in-Docker is used via access to the host socket - refer to `devcontainer.json` for details.

> I build in Docker on Windows using WSL-2 as the backend engine. Other build environments have not been tested.

The build process itself is blocking so that it completes only when the unattended Windows installation has actually finished, along with the post-install configuration.  

Start the build with:

`./build.sh`

This goes through the process of:

- Setting up an SSH server (via Docker) which is used for reverse proxying VNC traffic back to the host since Docker build does not support port forwarding 
- Downloading the Windows 11 ISO and associated installation files
- Patching the ISO with `efisys_noprompt.bin` to initiate the installation automatically
- Modifying `autounattend.xml` to configure SSH server support along with RDP access and corresponding firewall rules
- Monitoring the install progress via SSH polling and gracefully terminating the QEMU image once complete

> During build, connect to `localhost:5905` via VNC (on the host) to observe the progress of graphical installer progress and facilitate debugging
