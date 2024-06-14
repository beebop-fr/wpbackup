#!/bin/bash

# This script has initially been generated by ChatGPT.
# Prompts used:
# - Write a bash script to save a wordpress website into a zip archive. The zip archive should contain the wp-content folder inside a subfolder called files and a backup.sql file at the root of the archive which is a dump of the wordpress website database.
# - The script should extract DB_ variables from wp-config.php
# - Take WP_PATH from the first arg, working dir by default, BACKUP_PATH working dir by default
# - Use /tmp as temporary folder
# - Add time token in the temp folder to prevent issue if running concurrent
# - Error if wp-config.php does not exist in wp_path
# - Make sure dot files are also backed up
# - Add an optional command line arg to specify the name of the backup file (keeping the date token)
# - Add a help message if the wrong number of arguments is provided
# - In the backup subdirectories files, also add the .htaccess file from the backed up wordpress directory
# - Add an option to backup all the existing files from wp directory, not only wp-content and .htaccess

# Function to display help message
display_help() {
  echo "Usage: $0 [WP_PATH] [BACKUP_NAME] [--all]"
  echo
  echo "WP_PATH      Path to the WordPress installation. Defaults to the current directory."
  echo "BACKUP_NAME  Optional name for the backup file (without date and .zip extension)."
  echo "--all        Backup all files in the WordPress directory, not just wp-content and .htaccess."
  echo
  echo "Example:"
  echo "  $0 /path/to/wordpress my_backup --all"
}

# Check for help option or no arguments
if [[ $1 == "--help" ]] || [[ $# -eq 0 ]]; then
  display_help
  exit 0
fi

# Set default paths
WP_PATH=${1:-$(pwd)}
BACKUP_PATH=$(pwd)
BACKUP_NAME=${2:-wordpress_backup}
BACKUP_ALL=false
if [[ $3 == "--all" ]]; then
  BACKUP_ALL=true
fi
BACKUP_FILE="${BACKUP_NAME}_$(date +%F).zip"
TEMP_PATH="/tmp/wordpress_backup_$(date +%s)"

# Check if wp-config.php exists
if [ ! -f "$WP_PATH/wp-config.php" ]; then
  echo "Error: wp-config.php not found in $WP_PATH"
  exit 1
fi

# Extract DB credentials from wp-config.php
DB_NAME=$(grep -oP "define\(\s*'DB_NAME',\s*'\K[^']+" $WP_PATH/wp-config.php)
DB_USER=$(grep -oP "define\(\s*'DB_USER',\s*'\K[^']+" $WP_PATH/wp-config.php)
DB_PASSWORD=$(grep -oP "define\(\s*'DB_PASSWORD',\s*'\K[^']+" $WP_PATH/wp-config.php)
DB_HOST=$(grep -oP "define\(\s*'DB_HOST',\s*'\K[^']+" $WP_PATH/wp-config.php)

# Step 1: Create a database dump
echo "Creating database dump..."
mkdir -p $TEMP_PATH
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME > $TEMP_PATH/backup.sql

# Step 2: Copy files to the temporary location
echo "Copying files..."
mkdir -p $TEMP_PATH/files

if [ "$BACKUP_ALL" = true ]; then
  cp -r $WP_PATH/* $TEMP_PATH/files/
  cp -r $WP_PATH/.* $TEMP_PATH/files/ 2>/dev/null || :
else
  shopt -s dotglob
  cp -r $WP_PATH/wp-content $TEMP_PATH/files/
  if [ -f "$WP_PATH/.htaccess" ]; then
    cp $WP_PATH/.htaccess $TEMP_PATH/files/
  fi
fi

# Step 3: Create a zip archive containing the backup.sql and files folder
echo "Creating zip archive..."
cd $TEMP_PATH
zip -r $BACKUP_PATH/$BACKUP_FILE backup.sql files/

# Step 4: Clean up temporary files
echo "Cleaning up temporary files..."
rm -rf $TEMP_PATH

echo "Backup completed: $BACKUP_PATH/$BACKUP_FILE"
