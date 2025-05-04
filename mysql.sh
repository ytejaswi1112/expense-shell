#!/bin/bash

# Variables
USERID=$(id -u)
TIMESTAMP=$(date +%F-%H-%M-%S)
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
LOGFILE="/tmp/${SCRIPT_NAME}-${TIMESTAMP}.log"
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

# Prompt for MySQL root password
echo "Please enter MySQL root password:"
read -s mysql_root_password

# Function to validate the previous command's status
VALIDATE() {
  if [ $1 -ne 0 ]; then
    echo -e "$2...$R FAILURE $N"
    echo "$2... FAILURE" >> "$LOGFILE"
    exit 1
  else
    echo -e "$2...$G SUCCESS $N"
    echo "$2... SUCCESS" >> "$LOGFILE"
  fi
}

# Ensure the script is run as root
if [ "$USERID" -ne 0 ]; then
  echo -e "$R Please run this script as root user $N"
  exit 1
fi

echo -e "$G You are running as root user. $N"

# Install MySQL server
dnf install mysql-server -y &>> "$LOGFILE"
VALIDATE $? "Installing MySQL Server"

# Enable and start MySQL service
systemctl enable mysqld &>> "$LOGFILE"
VALIDATE $? "Enabling MySQL Service"

systemctl start mysqld &>> "$LOGFILE"
VALIDATE $? "Starting MySQL Service"

# Check if MySQL is active
systemctl is-active --quiet mysqld
VALIDATE $? "Verifying MySQL Service Status"

# Try connecting to MySQL using the given password
mysql -u root -p"${mysql_root_password}" -e "SHOW DATABASES;" &>> "$LOGFILE"
if [ $? -ne 0 ]; then
  echo "Setting up root password..."
  temp_pass=$(grep 'temporary password' /var/log/mysqld.log | tail -1 | awk '{print $NF}')

  mysql --connect-expired-password -u root -p"${temp_pass}" <<EOF &>> "$LOGFILE"
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
UNINSTALL COMPONENT 'file://component_validate_password';
EOF

  VALIDATE $? "Setting up new MySQL root password"
else
  echo -e "MySQL root password already set...$Y SKIPPING PASSWORD SETUP $N"
fi