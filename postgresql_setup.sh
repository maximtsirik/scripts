#!/bin/bash

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}The script must be run as root.${NC}"
    exit 1
fi

DB_NAME="mydatabase"        # Replace with the desired database name
DB_USER="dbuser"            # Replace with the desired username

# Prompt the user for a password for security
echo -e "${YELLOW}Enter a password for user ${DB_USER}:${NC}"
read -s DB_PASSWORD
echo

echo -e "${BLUE}=== Updating the system and installing required packages ===${NC}"
apt-get update -qq && apt-get upgrade -y -qq
apt-get install -y -qq wget curl gnupg2 lsb-release ca-certificates ufw

echo -e "${BLUE}=== Adding the official PostgreSQL repository ===${NC}"
# Import the GPG key and save it to /usr/share/keyrings
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
    gpg --dearmor -o /usr/share/keyrings/postgresql.gpg

# Add the PostgreSQL repository using the key
echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list

echo -e "${BLUE}=== Installing PostgreSQL and PostGIS ===${NC}"
apt-get update -qq
apt-get install -y -qq postgresql-17 postgresql-17-postgis-3

echo -e "${BLUE}=== Configuring the firewall ===${NC}"
ufw allow ssh > /dev/null
ufw deny 5432/tcp > /dev/null
ufw --force enable > /dev/null

echo -e "${BLUE}=== Configuring PostgreSQL settings ===${NC}"
PG_CONF="/etc/postgresql/17/main/postgresql.conf"
PG_HBA="/etc/postgresql/17/main/pg_hba.conf"

# Configure PostgreSQL to listen only on localhost
sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" $PG_CONF

# Set the password encryption method
sed -i "s/#password_encryption = on/password_encryption = scram-sha-256/" $PG_CONF

# Configure pg_hba.conf to allow only local connections
cat > $PG_HBA <<EOF
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections via Unix sockets
local   all             all                                     scram-sha-256

# IPv4 local connections
host    all             all             127.0.0.1/32            scram-sha-256

# IPv6 local connections
host    all             all             ::1/128                 scram-sha-256
EOF

echo -e "${BLUE}=== Restarting PostgreSQL service ===${NC}"
systemctl restart postgresql

echo -e "${BLUE}=== Creating the database and user ===${NC}"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" > /dev/null
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" > /dev/null
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" > /dev/null
sudo -u postgres psql -d $DB_NAME -c "CREATE EXTENSION postgis;" > /dev/null

echo -e "${GREEN}Installation and configuration completed successfully!${NC}"
