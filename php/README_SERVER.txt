Federated Learning App - Server Deployment Guide
==================================================

These files constitute the backend API and Federated Learning automation server.

1. PREREQUISITES
----------------
- OS: Linux (Ubuntu/CentOS) or macOS
- Web Server: Apache or Nginx
- Language: PHP 7.4+
- Database: MySQL or MariaDB
- Automation: Python 3

2. INSTALLATION
---------------
1. Copy Folder:
   Place the contents of this folder into your web server's document root or a subdirectory.
   Example: /var/www/html/api/

2. Database Setup:
   - Create a new MySQL database (e.g., `federated_ml_db`).
   - Import the `schema.sql` file to create the required tables.
     Command: `mysql -u root -p federated_ml_db < schema.sql`

3. Configuration:
   - Open `db_connect.php` in a text editor.
   - Update the variables ($servername, $username, $password, $dbname) to match your server's credentials.

4. Permissions:
   Ensure the web server can write to the 'uploads', 'fl_updates', and 'models' folders.
   Command: 
     chmod -R 755 uploads fl_updates models
     chown -R www-data:www-data uploads fl_updates models

3. AUTOMATION SETUP (Federated Learning)
----------------------------------------
To enable the automated monthly model training:
1. Open a terminal in this directory.
2. Run the setup script:
   sh setup_cron.sh

This will verify the Python environment and schedule the training job to run on the 1st of every month.

4. VERIFICATION
---------------
- Visit `http://your-server-ip/api/auth.php` in a browser. 
- If you see `{"status":"error","message":"Invalid action"}`, the API is working correctly.
