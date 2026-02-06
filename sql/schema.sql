SET FOREIGN_KEY_CHECKS = 0;
CREATE DATABASE IF NOT EXISTS federated_ml_db;
USE federated_ml_db;

-- Users Table
DROP TABLE IF EXISTS users;
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    otp_code VARCHAR(6),
    otp_expires_at DATETIME,
    is_verified BOOLEAN DEFAULT 0
);

-- Scans Table (Synced History)
CREATE TABLE IF NOT EXISTS scans (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_email VARCHAR(100) NOT NULL,
    patient_id VARCHAR(50),
    patient_name VARCHAR(100),
    image_path VARCHAR(255) NOT NULL, -- Path to uploaded image
    result VARCHAR(50),
    confidence FLOAT,
    timestamp DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE
);

-- Federated Learning Updates
CREATE TABLE IF NOT EXISTS training_updates (
    id INT AUTO_INCREMENT PRIMARY KEY,
    client_id VARCHAR(100),
    update_path VARCHAR(255) NOT NULL, -- Path to gradient JSON/file
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
