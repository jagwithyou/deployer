

sudo apt install ssmtp

sudo apt install mailutils

sudo nano /etc/ssmtp/ssmtp.conf


#
# Config file for sSMTP sendmail
#
# The person who gets all mail for userids < 1000
# Make this empty to disable rewriting.
root=postmaster

# The place where the mail goes. The actual machine name is required no 
# MX records are consulted. Commonly mailhosts are named mail.domain.com
mailhub=smtp.gmail.com:587

# Where will the mail seem to come from?
#rewriteDomain=

# The full hostname
hostname=smtp
AuthUser=jag@sulopa.com
AuthPass=Jag143Sulopa
FromLineOverride=YES
UseSTARTTLS=YES

# Are users allowed to set their own From: address?
# YES - Allow the user to specify their own From: address
# NO - Use the system generated From: address
#FromLineOverride=YES




echo "Here add your email body" | mail -s "Here specify your email subject" your_recepient_email@yourdomain.com

echo "Message Body Here" | mail -s "Subject Here" jagwithyou@gmail.com -A setup.sh