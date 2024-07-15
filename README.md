# Notes

This is a pre-built Windows 11 Docker image. Unlike other implementations of Windows-in-Docker, the installation is actually part of the build process. Simply pull the image and you have a ready-to-use Windows installation.

# Run

Tested and working in WSL-2 (i.e. Windows Host => WSL-2 => Docker => QEMU => Win-11).

Usage:

`docker run -it --device=/dev/kvm win-docker:latest`

> **Note:** You must pass the `/dev/kvm` device flag in order for QEMU to use virtualization on the host

Once running, the image supports:

- RDP: Port 3389
- VNC: Port 5900
- Spice: Port 9843
- File Share (see below)

If you need a host directory to be accessible within the Windows image, just bind to volume to `/root/win-docker/samba/`:

> TODO: docker run --rm -it -p 5900:5900 --device=/dev/kvm -v C:/Users/sebbo/OneDrive/Desktop/tmp:/root/win-docker/samba win-docker

# Examples

The entrypoint launches the QEMU image and is blocking until Windows has booted. This means that you can use Docker `RUN` for composing your own post-launch environment. For example:

```
FROM win-docker:latest
RUN powershell
RUN
```

# Build

For convenience, this repository is configured with a devcontainer specification . Docker-in-Docker is used via access to the host socket - refer to `devcontainer.json` for details.

> I build in Docker on Windows using WSL-2 as the backend engine. Other build environments have not been tested!

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
