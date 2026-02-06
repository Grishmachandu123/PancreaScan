<?php
require 'db_connect.php';

header('Content-Type: application/json');

$action = $_POST['action'] ?? '';

if ($action == 'upload_gradients') {
    $client_id = $_POST['client_id'] ?? 'unknown';
    $gradients = $_POST['gradients'] ?? ''; // JSON string or file path
    
    // Save gradients to a file
    $filename = "fl_updates/grad_" . uniqid() . ".json";
    if (!is_dir("fl_updates")) mkdir("fl_updates");
    file_put_contents($filename, $gradients);
    
    // Log to DB
    $stmt = $conn->prepare("INSERT INTO training_updates (client_id, update_path) VALUES (?, ?)");
    $stmt->bind_param("ss", $client_id, $filename);
    $stmt->execute();
    
    echo json_encode(["status" => "success", "message" => "Gradients received"]);

} elseif ($action == 'get_global_model') {
    // Serve the latest tflite model
    // Assuming 'model.tflite' is in the root or a 'models' folder
    
    // Read version from file
    $version_file = "models/version.txt";
    if (file_exists($version_file)) {
        $model_version = trim(file_get_contents($version_file));
    } else {
        $model_version = "1.0.0";
    }
    $model_url = "http://14.139.187.229:8000" . dirname($_SERVER['REQUEST_URI']) . "/models/pancreas.tflite";
    
    echo json_encode([
        "status" => "success", 
        "version" => $model_version,
        "download_url" => $model_url
    ]);

} else {
    echo json_encode(["status" => "error", "message" => "Invalid action"]);
}

$conn->close();
?>
