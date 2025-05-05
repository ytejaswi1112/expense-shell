#!/bin/bash

USERID=$(id -u)
TIMESTAMP=$(date +%F-%H-%M-%S)
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
LOGFILE="/tmp/${SCRIPT_NAME}-${TIMESTAMP}.log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

echo -e "Please enter MySQL root password you want to set:"
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
    echo -e "${R}Please run this script with root access.${N}"
    exit 1
else
    echo -e "You are super user."
fi

echo -e "Installing MySQL Server..."
dnf install mysql-server -y &>>"$LOGFILE"
VALIDATE $? "Installing MySQL Server"

systemctl enable mysqld &>>"$LOGFILE"
VALIDATE $? "Enabling MySQL Service"

systemctl start mysqld &>>"$LOGFILE"
VALIDATE $? "Starting MySQL Service"

echo -e "Verifying MySQL Service Status..."
systemctl is-active --quiet mysqld
VALIDATE $? "MySQL Service Status"

# Try logging in with provided password
mysql -u root -p"${mysql_root_password}" -e "SHOW DATABASES;" &>>"$LOGFILE"
if [ $? -ne 0 ]; then
    echo -e "$Y MySQL root password doesn't work. Attempting reset... $N"

    echo -e "$Y Stopping MySQL for reset... $N"
    systemctl stop mysqld &>>"$LOGFILE"
    VALIDATE $? "Stopping MySQL"

    echo -e "$Y Starting MySQL in skip-grant-tables mode... $N"
    mysqld_safe --skip-grant-tables &>>"$LOGFILE" &
    sleep 5

    for i in {1..10}; do
        mysqladmin ping &>/dev/null && break
        echo "Waiting for MySQL to be ready ($i/10)..."
        sleep 2
    done

    echo -e "$Y Resetting root password... $N"
    mysql -uroot <<EOF &>>"$LOGFILE"
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
EOF
    VALIDATE $? "Resetting MySQL root password"

    echo -e "$Y Killing MySQL safe mode... $N"
    pkill -f mysqld_safe &>>"$LOGFILE"
    pkill -f mysqld &>>"$LOGFILE"
    sleep 5

    echo -e "$Y Restarting MySQL normally... $N"
    systemctl start mysqld &>>"$LOGFILE"
    VALIDATE $? "Restarting MySQL"
else
    echo -e "MySQL root password is already working...$Y SKIPPING RESET $N"
fi