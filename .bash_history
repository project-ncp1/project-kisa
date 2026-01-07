init 0
vim /etc/ssh/sshd_config
vim /etc/sshd_config
cat /etc/sshd_config
su
vim /etc/security/pwquality.conf
vim /etc/pam.d/system-auth
dns install pam_pwquality
dnf install pam_pwquality
su
init 0
su
faillock --user wnsdud0344
su
su 
init 1
init 0
faillock --user wnsdud0344
su
init 1
init 0
exit
faillock --user wnsdud0344
sudo systemctl status sshd
ssh wnsdud0344@localhost
faillock --user wnsdud0344
vim /etc/pam.d/system-auth
vim /etc/pam.d/password-auth
vim /etc/pam.d/sshd
vim /etc/pam.d/password-auth
vim /etc/pam.d/sshd
su
faillock --user -wnsdud0344
sudo authselect select sssd with-faillock --force
sudo authselect apply-changes
vim /etc/security/fillock.conf
vim /etc/security/faillock.conf
su
init 0
su
