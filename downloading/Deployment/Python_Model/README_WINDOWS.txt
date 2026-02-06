Federated Learning App - Windows Server Deployment Guide
=========================================================

1. PREREQUISITES
----------------
- Software: XAMPP (installed at C:\xampp usually) OR just PHP installed manually.
- Python: Python 3.x installed (Tick "Add Python to PATH" during installation).

2. SETUP WITH XAMPP
-------------------
1. Copy Folder:
   Copy the `php_api` folder into `C:\xampp\htdocs\`
   (So it looks like C:\xampp\htdocs\php_api\)

2. Database Setup:
   - Open XAMPP Control Panel and start "Apache" and "MySQL".
   - Go to http://localhost/phpmyadmin/ in your browser.
   - Click "New", name it `federated_ml_db`, and Create.
   - Click "Import" tab, choose `schema.sql` from this folder, and click "Go".

3. Configuration:
   - Open `db_connect.php`.
   - Ensure settings are:
     $servername = "localhost";
     $username = "root";
     $password = ""; (Default XAMPP password is empty)
     $dbname = "federated_ml_db";

4. Python Dependencies:
   - Open Command Prompt (cmd) in this folder.
   - Run: `pip install -r requirements.txt`

3. RUNNING THE SERVER
---------------------
Double-click `start_server.bat`.

OR rely on XAMPP Apache:
- If you put it in htdocs, it is already running at:
  `http://YOUR_IP_ADDRESS/php_api/`
- You don't need to run a separate Start script if Apache is on.

4. AUTOMATION (TRAINING)
------------------------
To train the model manually:
- Double-click `run_training.bat`

To run it automatically (e.g., daily):
1. Open "Task Scheduler" in Windows.
2. Create Basic Task -> Name: "FL Train" -> Daily.
3. Action: Start a Program.
4. Program/script: `C:\xampp\htdocs\php_api\run_training.bat`
