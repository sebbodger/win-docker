from textwrap import dedent
from pathlib import Path

def write_conf():

    # set-up port forwards for rdp

    base_str = dedent("""
        #!/usr/bin/quickemu --vm

        guest_os="windows"
        disk_img="windows-11/disk.qcow2"
        iso="windows-11/windows-11.iso"
        fixed_iso="windows-11/virtio-win.iso"
        tpm="on"
        secureboot="off"
        ram="8G"
        cpu_cores="4"
        port_forwards=("3389:3389")
        disk_size="30G"
    """).strip('\n')

    quickemu_conf = Path.cwd() / 'windows-11.conf'

    with open(quickemu_conf,'w') as out:
        out.write(base_str)

if __name__ == "__main__":
    write_conf()