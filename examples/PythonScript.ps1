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