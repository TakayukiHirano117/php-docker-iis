FROM mcr.microsoft.com/windows/servercore/iis

ENV PHP_DOWNLOAD_URL https://windows.php.net/downloads/releases/archives/php-8.2.20-nts-Win32-vs16-x64.zip
ENV VC_REDIST_URL 	https://aka.ms/vs/17/release/vc_redist.x64.exe
ENV PHP_INSTALL_DIR C:\\inetpub\\php
ENV PHP_CGI C:\\inetpub\\php\\php-cgi.exe
ENV APPCMD_PATH C:\\Windows\\System32\\inetsrv\\appcmd.exe

SHELL ["powershell", "-NoProfile", "-Command"]

RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest -Uri $env:PHP_DOWNLOAD_URL -OutFile 'php.zip'; \
    New-Item -Path $env:PHP_INSTALL_DIR -ItemType Directory -Force; \
    Expand-Archive -Path 'php.zip' -DestinationPath $env:PHP_INSTALL_DIR; \
    Remove-Item -Path 'php.zip' -Force;

RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest -Uri $env:VC_REDIST_URL -OutFile "vc_redist.x64.exe"; \
    Start-Process -FilePath "vc_redist.x64.exe" -ArgumentList "/install", "/quiet", "/norestart" -NoNewWindow -Wait; \
    Remove-Item -Path "vc_redist.x64.exe" -Force;

RUN Import-Module IISAdministration; \
    Import-Module WebAdministration; \
    Install-WindowsFeature Web-CGI; \
    Install-WindowsFeature Web-Scripting-Tools

RUN $registryPath = 'HKLM:\Software\Microsoft\IIS\Extensions'; \
    if (-Not (Test-Path $registryPath)) { New-Item -Path $registryPath -Force } ; \
    Set-ItemProperty -Path $registryPath -Name "php" -Value "$env:PHP_INSTALL_DIR\php-cgi.exe"

RUN icacls 'C:\inetpub\php' /grant 'IIS_IUSRS:(OI)(CI)F' /T
RUN icacls 'C:\inetpub\wwwroot' /grant 'IUSR:(OI)(CI)F' /T

RUN Add-WebConfigurationProperty -Filter 'system.webServer/fastCgi' -Name '.' -PSPath 'MACHINE/WEBROOT/APPHOST' -Value @{fullPath='C:\inetpub\php\php-cgi.exe'};

RUN Set-WebConfigurationProperty -Filter "system.webServer/fastCgi/application" -Name "." -PSPath "MACHINE/WEBROOT/APPHOST" -Value @{fullPath='C:\inetpub\php\php-cgi.exe'};

RUN New-WebHandler -Name "PHP_via_FastCGI" -Verb "*" -Path "*.php" -Modules "FastCgiModule" -ScriptProcessor 'C:\inetpub\php\php-cgi.exe' -resourceType "Either" -RequiredAccess "Script";

# RUN Remove-Item -Recurse "C:\inetpub\wwwroot\*"

WORKDIR C:\\inetpub\\wwwroot
COPY ./web .
# COPY ./php.ini $env:PHP_INSTALL_DIR\\php.ini
COPY ./php.ini ..\\php\\php.ini

EXPOSE 80
