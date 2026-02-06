# Deployment Guide

This guide explains how to deploy the **PancreaScan** backend, which consists of two parts:
1.  **PHP Backend:** Handles API requests, file uploads, and data storage.
2.  **Python Model:** Runs the Federated Learning training process.

## 1. PHP Backend Setup
This folder (`PHP_Backend`) should be hosted on a web server (Apache/Nginx) with PHP and MySQL.

### Commands to Run:
```bash
# 1. Move to web root (example for Ubuntu/Apache)
sudo cp -r PHP_Backend/* /var/www/html/pancreascan/

# 2. Set Permissions (Crucial for uploads)
sudo chown -R www-data:www-data /var/www/html/pancreascan/
sudo chmod -R 777 /var/www/html/pancreascan/uploads
sudo chmod -R 777 /var/www/html/pancreascan/models
sudo chmod -R 777 /var/www/html/pancreascan/fl_updates
```

### Database Setup
1.  Create a MySQL database named `federated_ml`.
2.  Import `schema.sql` into it.
3.  Update `db_connect.php` with your database credentials.

## 2. Python Model Setup
This folder (`Python_Model`) runs independently, usually as a background cron job.

### Commands to Run:
```bash
# 1. Install Dependencies
cd Python_Model
pip3 install -r requirements.txt

# 2. Test execution (It looks for ../PHP_Backend automatically)
python3 server_train.py
```

## 3. Automation (Cron Job)
To train the model automatically (e.g., every night or month):

```bash
# Open crontab
crontab -e

# Add this line to run on the 1st of every month at midnight
0 0 1 * * /usr/bin/python3 /path/to/Deployment/Python_Model/server_train.py >> /path/to/Deployment/Python_Model/training.log 2>&1
```
