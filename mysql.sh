#!/bin/bash

USERID=$(id -u)
TIMESTAMP=$(date +%F-%H-%M-%S)
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
LOGFILE="/tmp/${SCRIPT_NAME}-${TIMESTAMP}.log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

echo -e "${Y}Please enter MySQL root password you want to set:${N}"
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
    echo -e "${G}You are super user.${N}"
fi

echo -e "Installing MySQL Server..."
dnf install mysql-server -y &>>"$LOGFILE"
VALIDATE $? "Installing MySQL Server"

systemctl enable mysqld &>>"$LOGFILE"
VALIDATE $? "Enabling MySQL Service"

systemctl start mysqld &>>"$LOGFILE"
VALIDATE $? "Starting MySQL Service"

echo -e "Verifying MySQL root password..."
mysql -u root -p"${mysql_root_password}" -e "SHOW DATABASES;" &>>"$LOGFILE"
if [ $? -ne 0 ]; then
    echo -e "${Y}MySQL root password doesn't work. Attempting reset...${N}"

    echo -e "Stopping MySQL..."
    systemctl stop mysqld &>>"$LOGFILE"
    VALIDATE $? "Stopping MySQL"

    echo -e "Creating systemd override to use --skip-grant-tables..."
    mkdir -p /etc/systemd/system/mysqld.service.d
    cat <<EOF > /etc/systemd/system/mysqld.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/libexec/mysqld --skip-grant-tables --skip-networking
EOF

    systemctl daemon-reexec &>>"$LOGFILE"
    systemctl daemon-reload &>>"$LOGFILE"
    systemctl start mysqld &>>"$LOGFILE"
    sleep 5

    echo -e "Resetting MySQL root password..."
    mysql -u root <<EOF &>>"$LOGFILE"
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
EOF
    VALIDATE $? "Resetting MySQL root password"

    echo -e "Cleaning up systemd override..."
    rm -f /etc/systemd/system/mysqld.service.d/override.conf

    systemctl daemon-reexec &>>"$LOGFILE"
    systemctl daemon-reload &>>"$LOGFILE"
    systemctl restart mysqld &>>"$LOGFILE"
    VALIDATE $? "Restarting MySQL with new root password"

else
    echo -e "MySQL root password is already set...${Y} SKIPPING ${N}"
fi
