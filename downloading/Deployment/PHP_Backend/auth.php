<?php
require 'db_connect.php';

header('Content-Type: application/json');

require 'vendor/autoload.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

$action = $_POST['action'] ?? '';

function send_otp_email($email, $otp) {
    error_log("------------------------------------------");
    error_log("📧 [MOCK EMAIL LOG] To: $email");
    error_log("🔑 OTP Code: $otp");
    error_log("------------------------------------------");
    
    $mail = new PHPMailer(true);

    try {
        // Server settings
        $mail->isSMTP();
        $mail->Host       = 'smtp.gmail.com';
        $mail->SMTPAuth   = true;
        // ⚠️ REPLACE WITH YOUR EMAIL AND APP PASSWORD
        $mail->Username   = 'pancreascan.app@gmail.com'; 
        $mail->Password   = 'YOUR_GOOGLE_APP_PASSWORD_HERE'; 
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port       = 587;

        // Recipients
        $mail->setFrom('pancreascan.app@gmail.com', 'PancreaScan');
        $mail->addAddress($email);

        // Content
        $mail->isHTML(true);
        $mail->Subject = 'PancreaScan Verification Code';
        $mail->Body    = "
            <h2>Verify Your Email</h2>
            <p>Your verification code is: <strong>$otp</strong></p>
            <p>This code triggers account verification. Do not share it.</p>
        ";
        $mail->AltBody = "Your verification code is: $otp";

        $mail->send();
        error_log("✅ Email sent successfully to $email");
        return true;
    } catch (Exception $e) {
        error_log("❌ Message could not be sent. Mailer Error: {$mail->ErrorInfo}");
        return false;
    }
}

if ($action == 'signup') {
    $name = $_POST['name'] ?? '';
    $email = $_POST['email'] ?? '';
    $password = $_POST['password'] ?? '';

    // Enhanced Server-Side Validation
    if (empty($name) || empty($email) || empty($password)) {
        echo json_encode(["status" => "error", "message" => "Missing fields"]);
        exit();
    }
    
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        echo json_encode(["status" => "error", "message" => "Invalid email format"]);
        exit();
    }
    
    // Name validation (only letters and spaces)
    if (!preg_match("/^[a-zA-Z ]*$/", $name)) {
        echo json_encode(["status" => "error", "message" => "Name should only contain letters and white space"]);
        exit();
    }

    // Check if email exists
    $check = $conn->prepare("SELECT id FROM users WHERE email = ?");
    $check->bind_param("s", $email);
    $check->execute();
    $check->store_result();
    
    if ($check->num_rows > 0) {
        echo json_encode(["status" => "error", "message" => "Email already exists"]);
    } else {
        $hashed_password = password_hash($password, PASSWORD_DEFAULT);
        $otp = NULL;
        $expires = NULL;
        $is_verified = 1; // Auto-verify
        
        $stmt = $conn->prepare("INSERT INTO users (name, email, password, otp_code, otp_expires_at, is_verified) VALUES (?, ?, ?, ?, ?, ?)");
        $stmt->bind_param("sssssi", $name, $email, $hashed_password, $otp, $expires, $is_verified);
        
        if ($stmt->execute()) {
            echo json_encode([
                "status" => "success", 
                "message" => "User created successfully.", 
                "user_id" => $stmt->insert_id,
                "user" => [
                    "id" => $stmt->insert_id,
                    "name" => $name,
                    "email" => $email
                ]
            ]);
        } else {
            echo json_encode(["status" => "error", "message" => "Database error"]);
        }
    }

} elseif ($action == 'verify_otp') {
    $email = $_POST['email'] ?? '';
    $otp = $_POST['otp'] ?? '';
    
    $stmt = $conn->prepare("SELECT id, otp_code, otp_expires_at FROM users WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($row = $result->fetch_assoc()) {
        if ($row['otp_code'] == $otp && strtotime($row['otp_expires_at']) > time()) {
            // Success
            $update = $conn->prepare("UPDATE users SET is_verified = 1, otp_code = NULL, otp_expires_at = NULL WHERE email = ?");
            $update->bind_param("s", $email);
            $update->execute();
            
            // Get updated user info
            $u_stmt = $conn->prepare("SELECT id, name, email FROM users WHERE email = ?");
            $u_stmt->bind_param("s", $email);
            $u_stmt->execute();
            $user_data = $u_stmt->get_result()->fetch_assoc();
            
            echo json_encode(["status" => "success", "message" => "Verification successful", "user" => $user_data]);
        } else {
            echo json_encode(["status" => "error", "message" => "Invalid or expired OTP"]);
        }
    } else {
        echo json_encode(["status" => "error", "message" => "User not found"]);
    }

} elseif ($action == 'request_password_reset') {
    $email = $_POST['email'] ?? '';
    
    $stmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $otp = rand(100000, 999999);
        $expires = date("Y-m-d H:i:s", strtotime("+10 minutes"));
        
        $update = $conn->prepare("UPDATE users SET otp_code = ?, otp_expires_at = ? WHERE email = ?");
        $update->bind_param("sss", $otp, $expires, $email);
        $update->execute();
        
        send_otp_email($email, $otp);
        echo json_encode(["status" => "success", "message" => "OTP sent to email"]);
    } else {
        // For security, don't reveal if email strictly exists, but for UX we often say Sent.
        // Or user not found. Let's be explicit for this app.
        echo json_encode(["status" => "error", "message" => "Email not found"]);
    }

} elseif ($action == 'reset_password') {
    $email = $_POST['email'] ?? '';
    $otp = $_POST['otp'] ?? '';
    $new_password = $_POST['new_password'] ?? '';
    
    $stmt = $conn->prepare("SELECT id, otp_code, otp_expires_at FROM users WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($row = $result->fetch_assoc()) {
        if ($row['otp_code'] == $otp && strtotime($row['otp_expires_at']) > time()) {
            $hashed_password = password_hash($new_password, PASSWORD_DEFAULT);
            
            $update = $conn->prepare("UPDATE users SET password = ?, otp_code = NULL, otp_expires_at = NULL WHERE email = ?");
            $update->bind_param("ss", $hashed_password, $email);
            $update->execute();
            
            echo json_encode(["status" => "success", "message" => "Password updated. Please login."]);
        } else {
            echo json_encode(["status" => "error", "message" => "Invalid or expired OTP"]);
        }
    } else {
        echo json_encode(["status" => "error", "message" => "User not found"]);
    }

} elseif ($action == 'login') {
    $email = $_POST['email'] ?? '';
    $password = $_POST['password'] ?? '';

    $stmt = $conn->prepare("SELECT id, name, password, is_verified FROM users WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($row = $result->fetch_assoc()) {
        if (password_verify($password, $row['password'])) {
            echo json_encode([
                "status" => "success",
                "message" => "Login successful",
                "user" => [
                    "id" => $row['id'],
                    "name" => $row['name'],
                    "email" => $email
                ]
            ]);
        } else {
            echo json_encode(["status" => "error", "message" => "Invalid password"]);
        }
    } else {
        echo json_encode(["status" => "error", "message" => "User not found"]);
    }
} elseif ($action == 'delete_account') {
    $email = $_POST['email'] ?? '';
    // ... (existing delete logic)
    // 1. Delete associated scans and images first
    $stmt = $conn->prepare("SELECT image_path FROM scans WHERE user_email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    while ($row = $result->fetch_assoc()) {
        $path = $row['image_path'];
        if (file_exists($path)) unlink($path);
    }
    
    $stmt = $conn->prepare("DELETE FROM scans WHERE user_email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    
    // 2. Delete User
    $stmt = $conn->prepare("DELETE FROM users WHERE email = ?");
    $stmt->bind_param("s", $email);
    
    if ($stmt->execute()) {
        echo json_encode(["status" => "success", "message" => "Account deleted"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to delete account"]);
    }

} else {
    echo json_encode(["status" => "error", "message" => "Invalid action"]);
}

$conn->close();
?>
