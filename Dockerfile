FROM mcr.microsoft.com/windows/servercore/iis

ENV PHP_DOWNLOAD_URL https://windows.php.net/downloads/releases/archives/php-8.2.20-nts-Win32-vs16-x64.zip
ENV PHP_INSTALL_DIR C:\\inetpub\\php

SHELL ["powershell", "-NoProfile", "-Command"]

RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest -Uri $env:PHP_DOWNLOAD_URL -OutFile 'php.zip'; \
    New-Item -Path $env:PHP_INSTALL_DIR -ItemType Directory -Force; \
    Expand-Archive -Path 'php.zip' -DestinationPath $env:PHP_INSTALL_DIR; \
    Remove-Item -Path 'php.zip' -Force

RUN Import-Module IISAdministration; \
    Add-WindowsFeature Web-Scripting-Tools

COPY ./php.ini $env:PHP_INSTALL_DIR\php.ini

RUN $registryPath = 'HKLM:\Software\Microsoft\IIS\Extensions'; \
    if (-Not (Test-Path $registryPath)) { New-Item -Path $registryPath -Force } ; \
    Set-ItemProperty -Path $registryPath -Name "php" -Value "$env:PHP_INSTALL_DIR\php-cgi.exe"

RUN icacls 'C:\inetpub\wwwroot' /grant 'IUSR:(OI)(CI)F' /T
RUN icacls 'C:\inetpub\php' /grant 'IIS_IUSRS:(OI)(CI)F' /T

RUN Remove-Item -Recurse "C:\inetpub\wwwroot\*"

WORKDIR C:\\inetpub\\wwwroot
COPY . .


EXPOSE 80
