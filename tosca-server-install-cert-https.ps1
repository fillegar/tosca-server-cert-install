<# 
.SYNOPSIS
    Configures HTTPS binding for Tosca Server using an existing PKI-issued certificate.

.DESCRIPTION
    This script searches the LocalMachine\My certificate store for a certificate issued to a specific DNS name,
    and binds it to port 443 using netsh.

.PARAMETER DnsName
    The subject name (CN or SAN) of the certificate (e.g., toscaserver.internal.corp)

.NOTES
    Author: fillegar
    Created: 2023-06-09
#>

param (
    [string]$DnsName = "tosca-server.servername.com", # Use your server's DNS name
    [int]$Port = 443,
    [string]$AppId = "{00112233-4455-6677-8899-AABBCCDDEEFF}"  # Use your unique App ID
)

Write-Host "Searching for certificate with subject: $DnsName..."

# Step 1: Load cert from store
$certStore = Get-Item "cert:\LocalMachine\My"
$cert = $certStore\* | Where-Object { $_.Subject -like "*CN=$DnsName*" -or $_.Subject -like "*$DnsName*" } | Sort-Object NotAfter -Descending | Select-Object -First 1

if (-not $cert) {
    Write-Error "Certificate not found for $DnsName in LocalMachine\My. Make sure it’s installed."
    exit 1
}

$thumbprint = $cert.Thumbprint -replace " ", ""
Write-Host ""Found certificate: $($cert.Subject)"
Write-Host "Thumbprint: $thumbprint"

# Step 2: Remove existing binding
try {
    netsh http delete sslcert ipport=0.0.0.0:$Port | Out-Null
    Write-Host "Existing binding on port $Port removed"
} catch {
    Write-Warning "No existing binding found (that's OK)"
}

# Step 3: Bind cert using netsh
try {
    netsh http add sslcert ipport=0.0.0.0:$Port certhash=$thumbprint appid=$AppId certstorename=MY | Out-Null
    Write-Host "Successfully bound HTTPS cert to port $Port"
} catch {
    Write-Error "Failed to bind cert: $_"
    exit 1
}

Write-Host "`n Tosca Server is now HTTPS-enabled via PKI cert at: https://$DnsName/`n"
Write-Host "Make sure your DNS or hosts file resolves $DnsName to 127.0.0.1 or internal IP."
