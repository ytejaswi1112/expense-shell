#!/bin/bash

USERID=$(id -u)
TIMESTAMP=$(date +%F-%H-%M-%S)
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
LOGFILE="/tmp/${SCRIPT_NAME}-${TIMESTAMP}.log"
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

echo "Please enter MySQL root password:"
read -s mysql_root_password

VALIDATE() {
   if [ $1 -ne 0 ]; then
        echo -e "$2...$R FAILURE $N"
        exit 1
   else
        echo -e "$2...$G SUCCESS $N"
   fi
}

if [ "$USERID" -ne 0 ]; then
    echo "Please run this script with root access."
    exit 1
else
    echo "You are super user."
fi

dnf install mysql-server -y &>>"$LOGFILE"
VALIDATE $? "Installing MySQL Server"

systemctl enable mysqld &>>"$LOGFILE"
VALIDATE $? "Enabling MySQL Service"

systemctl start mysqld &>>"$LOGFILE"
VALIDATE $? "Starting MySQL Service"

# Check if root password already works
mysql -u root -p"${mysql_root_password}" -e "SHOW DATABASES;" &>>"$LOGFILE"
if [ $? -ne 0 ]; then
    echo "Setting root password..."
    temp_pass=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
    
    mysql --connect-expired-password -u root -p"$temp_pass" <<EOF &>>"$LOGFILE"
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
UNINSTALL COMPONENT 'file://component_validate_password';
EOF
    VALIDATE $? "MySQL Root Password Setup"
else
    echo -e "MySQL root password is already set...$Y SKIPPING $N"
fi