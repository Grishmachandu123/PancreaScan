<?php
require 'db_connect.php';

$sql = file_get_contents('../sql/schema.sql');

// Split SQL by semicolons to execute multiple queries
$queries = explode(';', $sql);

foreach ($queries as $query) {
    $query = trim($query);
    if (!empty($query)) {
        if ($conn->query($query) === TRUE) {
            echo "Successfully executed: " . substr($query, 0, 50) . "...\n";
        } else {
            echo "Error executing query: " . $conn->error . "\n";
        }
    }
}

$conn->close();
echo "Database reset complete.\n";
?>
