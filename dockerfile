# escape=`
ARG BASE
FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-$BASE

ENV sa_password="_" `
    attach_dbs="[]" `
    accept_eula="_" `
    sa_password_path="C:\ProgramData\Docker\secrets\sa-password" `
    before_startup="C:\before-startup" `
    after_startup="C:\after-startup" `
    iso_url="https://download.microsoft.com/download/7/c/1/7c14e92e-bdcb-4f89-b7cf-93543e7112d1/SQLServer2019-x64-ENU-Dev.iso"


LABEL org.opencontainers.image.authors="Michał Bednarz"
LABEL org.opencontainers.image.source="https://github."
LABEL org.opencontainers.image.description="An container image for MS SQL Server with Full Text Search"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
USER ContainerAdministrator

RUN $ProgressPreference = 'SilentlyContinue'; `
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); `
    choco feature enable -n allowGlobalConfirmation; `
    choco install --no-progress --limit-output 7zip sqlpackage dbatools ; `
    Invoke-WebRequest -UseBasicParsing -Uri $env:iso_url -OutFile c:\SQLServer.iso; `
        mkdir c:\installer; `
        7z x -y -oc:\installer .\SQLServer.iso; `
        .\installer\setup.exe /q /ACTION=Install /INSTANCENAME=MSSQLSERVER /FEATURES=SQLEngine,FULLTEXT /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS; `
        remove-item c:\SQLServer.iso -ErrorAction SilentlyContinue; `
        remove-item -recurse -force c:\installer -ErrorAction SilentlyContinue; `
    refreshenv; 

RUN $SqlServiceName = 'MSSQLSERVER'; `
    While (!(get-service $SqlServiceName -ErrorAction SilentlyContinue)) { Start-Sleep -Seconds 5 } ; `
    Stop-Service $SqlServiceName ; `
    $databaseFolder = 'c:\databases'; `
    mkdir $databaseFolder ; `
    $SqlWriterServiceName = 'SQLWriter'; `
    $SqlBrowserServiceName = 'SQLBrowser'; `
    Set-Service $SqlServiceName -startuptype automatic ; `
    Set-Service $SqlWriterServiceName -startuptype manual ; `
    Stop-Service $SqlWriterServiceName; `
    Set-Service $SqlBrowserServiceName -startuptype manual ; `
    Stop-Service $SqlBrowserServiceName; `
    $SqlTelemetryName = 'SQLTELEMETRY'; `
    Set-Service $SqlTelemetryName -startuptype manual ; `
    Stop-Service $SqlTelemetryName; `
    $id = ('mssql15.MSSQLSERVER'); `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver\supersocketnetlib\tcp\ipall') -name tcpdynamicports -value '' ; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver\supersocketnetlib\tcp\ipall') -name tcpdynamicports -value '' ; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver\supersocketnetlib\tcp\ipall') -name tcpport -value 1433 ; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver') -name LoginMode -value 2; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver') -name DefaultData -value $databaseFolder; `
    Set-itemproperty -path ('HKLM:\software\microsoft\microsoft sql server\' + $id + '\mssqlserver') -name DefaultLog -value $databaseFolder; 

WORKDIR c:\scripts
COPY start.ps1 c:\scripts\

CMD .\start.ps1