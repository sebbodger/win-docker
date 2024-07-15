import requests
from tqdm.auto import tqdm
from pathlib import Path
import subprocess
import shutil
import xml.etree.ElementTree as ET
from copy import deepcopy
from typing import List
from urllib.parse import urlparse
import re

QUICKEMU_DIR = Path.cwd() / 'windows-11'
BASE_ISO = QUICKEMU_DIR / 'windows-11.iso'
UNATTEND_XML = QUICKEMU_DIR / 'unattended' / 'autounattend.xml'
WIN11_URL = 'https://mirror.mika.moe/files/Win11_English_x64.iso'

def download_file(url:str, filepath:Path):
    response = requests.get(url, stream=True)
    total_size = int(response.headers.get("Content-Length", 0))

    with open(filepath, "wb") as file, tqdm(
        desc=filepath.name,
        total=total_size,
        unit="iB",
        unit_scale=True,
        unit_divisor=1024,
    ) as progress_bar:
        for data in response.iter_content(chunk_size=1024):
            size = file.write(data)
            progress_bar.update(size)

def download_files(file_list:List[str], download_dir:Path):
    download_dir.mkdir(parents=True, exist_ok=True)

    for file_url in file_list:
        parsed_url = urlparse(file_url)
        filename = Path(parsed_url.path).name
        filepath = download_dir / filename
        download_file(file_url, filepath)

def enable_no_prompt():

    # modify the base iso file to use efisys_noprompt.bin to enable auto-boot from install media
    subprocess.check_call(
        '7z x windows-11.iso -oiso-unpack',
        shell=True,
        cwd=QUICKEMU_DIR
    )

    subprocess.check_call(
        'mkisofs -b boot/etfsboot.com -no-emul-boot -c BOOT.CAT -iso-level 4 -J -l -D -N -joliet-long -relaxed-filenames -v -V "Custom" -udf -boot-info-table -eltorito-alt-boot -eltorito-boot efi/microsoft/boot/efisys_noprompt.bin -no-emul-boot -o install.iso -allow-limited-size iso-unpack',
        shell=True,
        cwd=QUICKEMU_DIR
    )

    # tidy-up
    shutil.rmtree(QUICKEMU_DIR / 'iso-unpack', ignore_errors=True)
    BASE_ISO.unlink()
    (QUICKEMU_DIR / 'install.iso').rename(BASE_ISO)


def create_unattend_xml():

    # extract the baseline auto-unattend xml from the quickget script

    quickget_loc = subprocess.check_output('which quickget', shell=True, text=True).strip()

    with open(Path(quickget_loc), "r", encoding='utf-8') as f:
        quickget_script = f.read()
    
    pattern = r'<\?xml version="1\.0" encoding="utf-8"\?>(.*?)</unattend>'
    xml = re.search(pattern, quickget_script, re.DOTALL).group(0)

    # ... now patch it...

    ET.register_namespace('', "urn:schemas-microsoft-com:unattend")
    ET.register_namespace('wcm', "http://schemas.microsoft.com/WMIConfig/2002/State")
    ET.register_namespace('xsi', "http://www.w3.org/2001/XMLSchema-instance")

    root = ET.fromstring(xml)

    # inject the locale settings into base quickemu config

    locale_defaults = """
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0409:00000409</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>en-US</UserLocale>
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
        </component>
    """

    node = root.find(".//*[@pass='windowsPE']")
    locale_tree = ET.fromstring(locale_defaults)
    node.insert(0, locale_tree)

    # add additional first-logon commands

    # "cmd.exe /c echo Waiting 30 seconds before mapping network drive... && timeout /t 30 /nobreak && net use H: \\10.0.2.4\qemu /persistent:yes",


    # commands = [
    #     "cmd.exe /c netsh advfirewall firewall set rule group='Network Discovery' new enable=Yes",
    #     "cmd.exe /c netsh advfirewall firewall set rule group='File and Printer Sharing' new enable=Yes",
    #     "powershell -New-PSDrive -Name 'H' -PSProvider FileSystem -Root '\\10.0.2.4\qemu' -Persist",
    #     "powershell Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0",
    #     "powershell Start-Service sshd",
    #     "powershell Set-Service -Name sshd -StartupType 'Automatic'"
    # ]

    # commands = [
    #     'cmd.exe /c netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes',
    #     'cmd.exe /c netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes',
    #     'cmd.exe /c net use H: \\\\10.0.2.4\\qemu /user:quickemu /persistent:yes',
    #     'powershell Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0',
    #     'powershell Start-Service sshd',
    #     'powershell Set-Service -Name sshd -StartupType Automatic'
    # ]

    commands = [
        r'cmd.exe /c netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes',
        r'cmd.exe /c netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes',
        r'cmd.exe /c net use H: \\10.0.2.4\qemu /user:Quickemu /persistent:yes',
        r'powershell.exe -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0"',
        r'powershell.exe -Command "Start-Service sshd"',
        r'powershell.exe -Command "Set-Service -Name sshd -StartupType Automatic"'
    ]

    node = root.find(".//*{urn:schemas-microsoft-com:unattend}FirstLogonCommands")
    last_item = node.getchildren()[-1]
    max_order = int(last_item.find('{urn:schemas-microsoft-com:unattend}Order').text)

    for i, x in enumerate(commands):

        dupe = deepcopy(last_item)
        dupe.find('{urn:schemas-microsoft-com:unattend}Order').text = str(max_order + i + 1)
        dupe.find('{urn:schemas-microsoft-com:unattend}CommandLine').text = x
        dupe.find('{urn:schemas-microsoft-com:unattend}Description').text = ''
        node.append(dupe)

    # enable rdp access and associated firewall rules

    node = root.find(".//*[@pass='specialize']")

    local_session = """
    <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
        <fDenyTSConnections>false</fDenyTSConnections>
    </component>
    """

    terminal_services = """
    <component name="Microsoft-Windows-TerminalServices-RDP-WinStationExtensions" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
        <UserAuthentication>0</UserAuthentication>
    </component>
    """

    networking = """
    <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
        <FirewallGroups>
            <FirewallGroup wcm:action="add" wcm:keyValue="RemoteDesktop">
                <Active>true</Active>
                <Group>Remote Desktop</Group>
                <Profile>all</Profile>
            </FirewallGroup>
        </FirewallGroups>
    </component>
    """

    for x in [local_session, terminal_services, networking]:
        node.append(ET.fromstring(x))

    # write all xml changes and create the unattended iso image
    
    ET.ElementTree(root).write(UNATTEND_XML)
    
    subprocess.check_call(
        'mkisofs -quiet -l -o unattended.iso unattended/',
        shell=True,
        cwd=QUICKEMU_DIR
    )


def download_setup_files():

    download_file(WIN11_URL, BASE_ISO)

    download_files(
        [
            'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso'
        ],
        QUICKEMU_DIR
    )

    download_files(
        [
            'https://www.spice-space.org/download/windows/spice-webdavd/spice-webdavd-x64-latest.msi',
            'https://www.spice-space.org/download/windows/vdagent/vdagent-win-0.10.0/spice-vdagent-x64-0.10.0.msi',
            'https://www.spice-space.org/download/windows/usbdk/UsbDk_1.0.22_x64.msi'
        ],
        QUICKEMU_DIR / 'unattended'
    )

if __name__ == "__main__":

    # ideally we would use quickget directly but it is non-determistic due to the use of mido
    # ... so, re-implement this process manually
    download_setup_files()

    # set-up efisys_noprompt.bin
    enable_no_prompt()

    # modify the baseline autounattend.xml with additional settings
    create_unattend_xml()