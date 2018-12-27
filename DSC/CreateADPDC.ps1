configuration CreateADPDC
{
   param
   (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName @{modulename="xActiveDirectory";RequiredVersion="2.18.0.0"}, xNetworking, @{modulename="xPSDesiredStateConfiguration";RequiredVersion="8.4.0.0"}, PSDesiredStateConfiguration, xStorage, xSMBShare
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)

    Node localhost
    {
        File Destination {
            DestinationPath = 'c:\ISOPath'
            Type = 'Directory'
            Ensure = 'Present'
            DependsOn = "[xADDomain]FirstDS"
        }
        xRemoteFile ExchangeISO 
        {
            DestinationPath = 'c:\ISOPath\ExchangeServer2016-x64-cu4.iso'
            Uri = 'https://download.microsoft.com/download/6/6/F/66F70200-E2E8-4E73-88F9-A1F6E3E04650/ExchangeServer2016-x64-cu11.iso'
            #Uri = 'https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/11.0/FreeBSD-11.0-RELEASE-amd64-bootonly.iso'  #test FreeBSD iso (veel kleiner...)
            DependsOn = "[File]Destination"
            MatchSource = $false
        }
        xRemoteFile UMCA {
            DestinationPath = 'c:\ISOPath\UcmaRuntimeSetup.exe'
            Uri = 'https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe'
            DependsOn = "[File]Destination"
            MatchSource = $false
        }
        xMountImage ISOMount {
          ImagePath = "c:\ISOPath\ExchangeServer2016-x64-cu4.iso"
          DriveLetter = 'X'
          DependsOn = "[xRemoteFile]ExchangeISO"
        }
        xSMBShare EXInstall {
          Name = 'EXInstall'
          Path = 'X:\'
          DependsOn = "[xMountImage]ISOMount"
          ReadAccess = 'everyone'
        }
        xSmbShare Install {
            Name = 'Install'
            Path = 'C:\ISOPath'
            DependsOn = "[File]Destination"
        }

        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        WindowsFeature DNS
        {
            Ensure = "Present"
            Name = "DNS"
        }

        WindowsFeature DnsTools
        {
            Ensure = "Present"
            Name = "RSAT-DNS-Server"
            DependsOn = "[WindowsFeature]DNS"
        }

        xDnsServerAddress DnsServerAddress
        {
            Address        = '127.0.0.1'
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn = "[WindowsFeature]DNS"
        }

        Script script1
        {
      	    SetScript = {
                Set-DnsServerDiagnostics -All $true
                Write-Verbose -Verbose "Enabling DNS client diagnostics"
            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = "[WindowsFeature]DNS"
        }

        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
            #DependsOn="[cDiskNoRestart]ADDataDisk"
        }

        xADDomain FirstDS
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath = "C:\NTDS"
            LogPath = "C:\NTDS"
            SysvolPath = "C:\SYSVOL"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }
   }
}