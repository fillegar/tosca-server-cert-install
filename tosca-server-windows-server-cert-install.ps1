# Configure-ToscaServer-SSL-WinServer.ps1
<#!
.SYNOPSIS
    Configures HTTPS bindings for Tosca Server on Windows Server using a PKI certificate.
    Supports locating an existing cert or auto-requesting via Active Directory Certificate Services.

.DESCRIPTION
    This script supports:
    - Finding an existing cert from LocalMachine\My
    - OR auto-requesting a cert from AD CS
    - Binding via IIS with either IP-based or host-header-based (SNI) binding

.PARAMETER DnsName
    FQDN for the Tosca Server (e.g., tosca-server.domain.com)

.PARAMETER UseSni
    Switch to enable host-header (SNI) binding. Otherwise uses IP-based binding.

.PARAMETER RequestFromADCS
    Switch to request the cert via AD CS auto-enrollment. Otherwise searches local store.

.NOTES
    Requires IIS role and WebAdministration module.
#>

param (
    [string]$DnsName = "tosca-server.domain.com",
    [switch]$UseSni = $false,
    [switch]$RequestFromADCS = $false
)

Import-Module WebAdministration

Write-Host "\n Starting Tosca Server SSL configuration for: $DnsName"

# Certificate store path
$certStorePath = "cert:\\LocalMachine\\My"

if ($RequestFromADCS) {
    Write-Host " Requesting certificate from AD Certificate Services..."
    $reqInf = @"
[Version]
Signature="$Windows NT$"
[NewRequest]
Subject = "CN=$DnsName"
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = CMC
KeyUsage = 0xa0
[RequestAttributes]
CertificateTemplate = WebServer
"@

    $reqFile = "$env:TEMP\\tosca-cert.inf"
    $rspFile = "$env:TEMP\\tosca-cert.rsp"
    Set-Content -Path $reqFile -Value $reqInf -Encoding ASCII

    certreq.exe -new $reqFile $rspFile | Out-Null
    certreq.exe -submit $rspFile | Out-Null
    certreq.exe -accept $rspFile | Out-Null

    Write-Host "Certificate requested and installed via AD CS."
}

# Find certificate in store
$cert = Get-ChildItem -Path $certStorePath | Where-Object {
    $_.Subject -like "*CN=$DnsName*" -or $_.Subject -like "*$DnsName*"
} | Sort-Object NotAfter -Descending | Select-Object -First 1

if (-not $cert) {
    Write-Error " Certificate not found for $DnsName in LocalMachine\\My store."
    exit 1
}

$thumbprint = $cert.Thumbprint

# Configure IIS binding
$siteName = "ToscaServer"
$port = 443

# Create or update site
if (-not (Test-Path "IIS:\\Sites\\$siteName")) {
    New-Item "IIS:\\Sites\\$siteName" -Bindings @{ protocol='http'; bindingInformation="*:80:" } -PhysicalPath "C:\\inetpub\\toscaserver" | Out-Null
    Write-Host "Created new IIS site: $siteName"
}

# Remove existing HTTPS binding
Get-WebBinding -Name $siteName -Protocol https -ErrorAction SilentlyContinue | Remove-WebBinding -Confirm:$false

# Add HTTPS binding
if ($UseSni) {
    New-WebBinding -Name $siteName -Protocol https -Port $port -HostHeader $DnsName
    Write-Host "Added HTTPS binding using SNI for $DnsName"
    New-Item "IIS:\\SslBindings\\0.0.0.0!443!$DnsName" -Thumbprint $thumbprint -SSLFlags 1 | Out-Null
} else {
    New-WebBinding -Name $siteName -Protocol https -Port $port -IPAddress "*"
    Write-Host "Added HTTPS binding using IP binding"
    New-Item "IIS:\\SslBindings\\0.0.0.0!443" -Thumbprint $thumbprint -SSLFlags 0 | Out-Null
}

Write-Host "\n HTTPS binding complete. Tosca Server is accessible at: https://$DnsName/"
Write-Host " Thumbprint: $thumbprint"
