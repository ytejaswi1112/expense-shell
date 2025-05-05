#!/bin/bash

USERID=$(id -u)
TIMESTAMP=$(date +%F-%H-%M-%S)
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
LOGFILE="/tmp/${SCRIPT_NAME}-${TIMESTAMP}.log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

echo "Please enter MySQL root password you want to set:"
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
    echo -e "$R Please run this script with root access. $N"
    exit 1
else
    echo -e "$G You are super user. $N"
fi

echo -e "$Y Installing MySQL Server... $N"
dnf install mysql-server -y &>>"$LOGFILE"
VALIDATE $? "Installing MySQL Server"

systemctl enable mysqld &>>"$LOGFILE"
VALIDATE $? "Enabling MySQL Service"

systemctl start mysqld &>>"$LOGFILE"
VALIDATE $? "Starting MySQL Service"

# Check if the root password already works
mysql -uroot -p"${mysql_root_password}" -e "SHOW DATABASES;" &>>"$LOGFILE"
if [ $? -ne 0 ]; then
    echo -e "$Y MySQL root password doesn't work. Attempting reset... $N"

    echo -e "$Y Stopping MySQL for reset... $N"
    systemctl stop mysqld &>>"$LOGFILE"
    VALIDATE $? "Stopping MySQL"

    echo -e "$Y Starting MySQL in skip-grant-tables mode... $N"
    mysqld_safe --skip-grant-tables &>>"$LOGFILE" &
    sleep 5

    echo -e "$Y Resetting root password... $N"
    mysql -uroot <<EOF &>>"$LOGFILE"
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
EOF
    VALIDATE $? "Resetting MySQL root password"

    pkill -f mysqld_safe &>>"$LOGFILE"
    sleep 3

    echo -e "$Y Restarting MySQL normally... $N"
    systemctl start mysqld &>>"$LOGFILE"
    VALIDATE $? "Restarting MySQL"
else
    echo -e "MySQL root password already set...$Y SKIPPING PASSWORD RESET $N"
fi