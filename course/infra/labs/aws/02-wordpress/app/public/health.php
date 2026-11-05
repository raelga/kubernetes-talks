<?php
// ALB liveness deliberately does not claim database/application readiness.
declare(strict_types=1);
header('Content-Type: application/json');
header('Cache-Control: no-store');
$filesReady = is_file(__DIR__ . '/wp-settings.php') && is_file(__DIR__ . '/wp-admin/install.php');
http_response_code($filesReady ? 200 : 503);
echo json_encode(['web' => $filesReady ? 'ready' : 'missing-wordpress-files', 'database_checked' => false]);
