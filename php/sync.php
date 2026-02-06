<?php
require 'db_connect.php';

header('Content-Type: application/json');

$action = $_POST['action'] ?? '';

if ($action == 'upload_scan') {
    $user_email = $_POST['user_email'] ?? '';
    $image_data = $_POST['image'] ?? ''; // Base64 encoded
    $result = $_POST['result'] ?? '';
    $confidence = $_POST['confidence'] ?? 0.0;
    $patient_id = $_POST['patient_id'] ?? '';
    $patient_name = $_POST['patient_name'] ?? '';
    $timestamp = $_POST['timestamp'] ?? date("Y-m-d H:i:s");

    if (empty($user_email) || empty($image_data)) {
        echo json_encode(["status" => "error", "message" => "Missing data"]);
        exit();
    }

    // Decode Image
    // Fix: Replace spaces with + (common issue with form-urlencoded POST)
    $image_data = str_replace(' ', '+', $image_data);
    
    // Fix: Strip data URI scheme if present
    if (preg_match('/^data:image\/(\w+);base64,/', $image_data, $type)) {
        $image_data = substr($image_data, strpos($image_data, ',') + 1);
        $type = strtolower($type[1]); // jpg, png, etc.
    }

    $image = base64_decode($image_data);

    if ($image === false) {
        echo json_encode(["status" => "error", "message" => "Base64 decode failed"]);
        exit();
    }

    $filename = "uploads/" . uniqid() . ".jpg";
    if (!is_dir("uploads")) {
        if (!mkdir("uploads", 0777, true)) {
            // Try one more time with full path if relative fails, or just error out
            $lastError = error_get_last();
            echo json_encode(["status" => "error", "message" => "Failed to create uploads directory: " . ($lastError['message'] ?? 'Unknown error')]);
            exit();
        }
        chmod("uploads", 0777); // Explicitly set permissions
    }
    
    // Compress and save image
    $im = @imagecreatefromstring($image);
    if ($im !== false) {
        // Save as JPEG with 60% quality to reduce size
        $saved = imagejpeg($im, $filename, 60);
        imagedestroy($im);
        
        if (!$saved) {
             echo json_encode(["status" => "error", "message" => "Failed to compress and save image."]);
             exit();
        }
    } else {
        // Fallback: save raw data if compression fails
        if (file_put_contents($filename, $image) === false) {
            echo json_encode(["status" => "error", "message" => "Failed to write image file. Check permissions or size limits."]);
            exit();
        }
    }

    $stmt = $conn->prepare("INSERT INTO scans (user_email, image_path, result, confidence, patient_id, patient_name, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)");
    $stmt->bind_param("sssdsss", $user_email, $filename, $result, $confidence, $patient_id, $patient_name, $timestamp);

    if ($stmt->execute()) {
        echo json_encode(["status" => "success", "scan_id" => $stmt->insert_id]);
    } else {
        echo json_encode(["status" => "error", "message" => "Database error: " . $stmt->error]);
    }

} elseif ($action == 'get_history') {
    $user_email = $_POST['user_email'] ?? '';
    
    $stmt = $conn->prepare("SELECT * FROM scans WHERE user_email = ? ORDER BY timestamp DESC");
    $stmt->bind_param("s", $user_email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $history = [];
    while ($row = $result->fetch_assoc()) {
        $history[] = $row;
    }
    
    echo json_encode(["status" => "success", "history" => $history]);
} elseif ($action == 'clear_history') {
    $user_email = $_POST['user_email'] ?? '';
    
    // First, get all image paths to delete files
    $stmt = $conn->prepare("SELECT image_path FROM scans WHERE user_email = ?");
    $stmt->bind_param("s", $user_email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    while ($row = $result->fetch_assoc()) {
        $path = $row['image_path'];
        if (file_exists($path)) {
            unlink($path);
        }
    }
    
    // Now delete from DB
    $stmt = $conn->prepare("DELETE FROM scans WHERE user_email = ?");
    $stmt->bind_param("s", $user_email);
    
    if ($stmt->execute()) {
        echo json_encode(["status" => "success", "message" => "History cleared"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Database error"]);
    }
} elseif ($action == 'delete_scan') {
    $user_email = $_POST['user_email'] ?? '';
    $timestamp = $_POST['timestamp'] ?? '';
    
    // Safety check
    if (empty($user_email) || empty($timestamp)) {
        echo json_encode(["status" => "error", "message" => "Missing parameters for deletion"]);
        exit();
    }
    
    // Get image path to delete file
    // Note: timestamps in DB might differ by seconds if we don't sync properly. 
    // Ideally we should match exactly.
    $stmt = $conn->prepare("SELECT image_path FROM scans WHERE user_email = ? AND timestamp = ?");
    $stmt->bind_param("ss", $user_email, $timestamp);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($row = $result->fetch_assoc()) {
        $path = $row['image_path'];
        if (file_exists($path)) {
            unlink($path);
        }
    }
    
    // Delete from DB
    $stmt = $conn->prepare("DELETE FROM scans WHERE user_email = ? AND timestamp = ?");
    $stmt->bind_param("ss", $user_email, $timestamp);
    
    if ($stmt->execute()) {
        echo json_encode(["status" => "success", "message" => "Scan deleted"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Database error"]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Invalid action"]);
}

$conn->close();
?>
