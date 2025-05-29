# 🔐 Configure Tosca Server HTTPS (PKI Certificate) – PowerShell Script

This PowerShell script binds an **existing internal PKI-issued SSL certificate** to **Tosca Server** running on **Windows 11** (temporary environment), enabling secure HTTPS communication over **port 443**.

> ⚠️ This setup is intended for internal demos, POCs, or lab environments. Not recommended for production use or external/public exposure.

---

## 📁 Script File

## ⚙️ Features

- Locates a valid certificate in the `LocalMachine\My` store using subject name or SAN
- Removes any existing SSL certificate binding on port 443
- Binds the found certificate to port 443 using `netsh`
- Enables HTTPS access to Tosca Server via your configured domain name

---

## ✅ Prerequisites

- Windows 11 (temporary test/demo host) 
- PowerShell (Administrator)
- Certificate already installed from an internal PKI into `LocalMachine > Personal`
- DNS name (CN or SAN) must match the name used in the certificate
- Port 443 must be open in Windows Firewall

---

## 🚀 Usage

1. **Clone or copy the script to the target machine**

2. **Open PowerShell as Administrator**

3. **Run the script with your Tosca Server DNS name**:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope Process -Force
   .\Configure-ToscaServer-SSL-PKI.ps1 -DnsName "tosca-server.internal.domain.com"
