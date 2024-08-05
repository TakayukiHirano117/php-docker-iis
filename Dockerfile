FROM mcr.microsoft.com/windows/servercore/iis

ENV PHP_DOWNLOAD_URL https://windows.php.net/downloads/releases/archives/php-8.2.20-nts-Win32-vs16-x64.zip
ENV PHP_INSTALL_DIR C:\\inetpub\\php
ENV PHP_CGI C:\\inetpub\\php\\php-cgi.exe
ENV APPCMD_PATH C:\\Windows\\System32\\inetsrv\\appcmd.exe

SHELL ["powershell", "-NoProfile", "-Command"]

RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest -Uri $env:PHP_DOWNLOAD_URL -OutFile 'php.zip'; \
    New-Item -Path $env:PHP_INSTALL_DIR -ItemType Directory -Force; \
    Expand-Archive -Path 'php.zip' -DestinationPath $env:PHP_INSTALL_DIR; \
    Remove-Item -Path 'php.zip' -Force

RUN Import-Module IISAdministration; \
    Import-Module WebAdministration; \
    Install-WindowsFeature Web-CGI; \
    Install-WindowsFeature Web-Scripting-Tools

COPY ./php.ini $env:PHP_INSTALL_DIR\php.ini

RUN $registryPath = 'HKLM:\Software\Microsoft\IIS\Extensions'; \
    if (-Not (Test-Path $registryPath)) { New-Item -Path $registryPath -Force } ; \
    Set-ItemProperty -Path $registryPath -Name "php" -Value "$env:PHP_INSTALL_DIR\php-cgi.exe"

RUN icacls 'C:\inetpub\php' /grant 'IIS_IUSRS:(OI)(CI)F' /T
RUN icacls 'C:\inetpub\wwwroot' /grant 'IUSR:(OI)(CI)F' /T

# RUN Set-WebConfigurationProperty -Filter 'system.webServer/fastCgi' -Name '.'  -PSPath 'IIS:\' -Value @{fullPath='C:\inetpub\php\php-cgi.exe';arguments='';maxInstances=4;idleTimeout='00:02:00';activityTimeout='00:00:30';requestTimeout='00:01:00';instanceMaxRequests=10000};
RUN Set-WebConfigurationProperty -Filter 'system.webServer/fastCgi' -Name '.' -PSPath 'IIS:\' -Value 'C:\inetpub\php\php-cgi.exe';

RUN New-WebHandler -Name "PHP_via_FastCGI" -Verb "*" -Path "*.php" -Modules "FastCgiModule" -ScriptProcessor 'C:\inetpub\php\php-cgi.exe' -resourceType "Either" -RequiredAccess "Script";

# RUN Remove-Item -Recurse "C:\inetpub\wwwroot\*"

WORKDIR C:\\inetpub\\wwwroot
COPY ./web .

EXPOSE 80
