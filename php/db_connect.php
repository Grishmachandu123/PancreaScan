<?php
$servername = "127.0.0.1";
$username = "root";
$password = "";
$dbname = "federated_ml_db";

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Connection failed: " . $conn->connect_error]));
}

// Ensure the database uses UTF-8
$conn->set_charset("utf8");
?>
