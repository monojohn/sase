#!/bin/bash

echo "======== AWS EC2 Security Audit Script ========"

# Check OS & Kernel Info
echo "[+] OS Info:"
uname -a
cat /etc/os-release

# Check for root login enabled
echo -e "\n[+] Root SSH Login Status:"
grep PermitRootLogin /etc/ssh/sshd_config

# Check for password authentication over SSH
echo -e "\n[+] SSH Password Authentication:"
grep PasswordAuthentication /etc/ssh/sshd_config

# Check listening ports and services
echo -e "\n[+] Open Network Ports:"
ss -tulnp

# List users with UID 0
echo -e "\n[+] Users with UID 0 (root-level access):"
awk -F: '($3 == "0") {print}' /etc/passwd

# Check for world-writable files
echo -e "\n[+] World-Writable Files (excluding /proc):"
find / -xdev -type f -perm -0002 ! -path "/proc/*" 2>/dev/null

# Look for private keys or AWS credentials in home dirs
echo -e "\n[+] Sensitive Files in Home Directories:"
find /home /root -type f \( -name "*.pem" -o -name "*.key" -o -name "credentials" -o -name ".aws" \) 2>/dev/null

# Check for running processes as root
echo -e "\n[+] Running Processes as root:"
ps -U root -u root u

# Check if ufw/firewalld/iptables is enabled
echo -e "\n[+] Firewall Status:"
if command -v ufw >/dev/null; then
    ufw status verbose
elif command -v firewall-cmd >/dev/null; then
    firewall-cmd --list-all
elif command -v iptables >/dev/null; then
    iptables -L -n -v
else
    echo "No firewall management tool detected."
fi

# Check if updates are available
echo -e "\n[+] Package Updates Available:"
if command -v apt >/dev/null; then
    apt update -qq && apt list --upgradable
elif command -v yum >/dev/null; then
    yum check-update
elif command -v dnf >/dev/null; then
    dnf check-update
fi

# Check for attached IAM role and credentials (Instance Metadata)
echo -e "\n[+] IAM Role and AWS Metadata:"
curl -s http://169.254.169.254/latest/meta-data/iam/info || echo "No IAM role attached."
curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/ || echo "No IAM credentials."

# Check cron jobs and scripts
echo -e "\n[+] Cron Jobs:"
for user in $(cut -f1 -d: /etc/passwd); do
    crontab -l -u $user 2>/dev/null
done
ls -l /etc/cron*

# Check for setuid/setgid binaries
echo -e "\n[+] SetUID/SetGID Binaries:"
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null

# Check instance metadata accessibility (SSRFX risk)
echo -e "\n[+] Instance Metadata Exposure Test:"
curl -s -H "Metadata-Flavor: Google" http://169.254.169.254/ || echo "No GCP-style metadata accessible (expected)"
curl -s http://169.254.169.254/latest/meta-data/ || echo "AWS metadata accessible"

echo -e "\n======== Audit Complete ========"
