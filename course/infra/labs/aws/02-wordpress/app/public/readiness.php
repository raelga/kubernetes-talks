<?php
declare(strict_types=1);
ini_set('display_errors', '0');
header('Content-Type: application/json');
header('Cache-Control: no-store');
if (!is_file('/etc/infra-lab/configured')) {
    http_response_code(503);
    echo json_encode(['application' => 'not-configured', 'database_checked' => false]);
    exit;
}
try {
    // Reuse the generated private constants without booting WordPress or its installer.
    define('INFRA_LAB_READINESS', true);
    require dirname(__DIR__) . '/wp-config.php';
    $connection = new PDO('mysql:host=' . DB_HOST . ';port=3306;dbname=' . DB_NAME . ';charset=utf8mb4', DB_USER, DB_PASSWORD, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT => 5,
        PDO::MYSQL_ATTR_SSL_CA => '/etc/infra-lab/global-bundle.pem',
        PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => true,
    ]);
    $connection->query('SELECT 1');
    $hasOptions = $connection->query("SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'wp_options'")->fetchColumn() !== false;
    // WordPress considers installation complete only after its site URL is stored.
    $installed = $hasOptions
        && (bool) $connection->query("SELECT option_value FROM wp_options WHERE option_name = 'siteurl' LIMIT 1")->fetchColumn();
    echo json_encode(['application' => $installed ? 'installed' : 'installer-ready', 'database' => 'connected']);
} catch (Throwable $error) {
    http_response_code(503);
    echo json_encode(['application' => 'not-ready', 'database' => 'unavailable']);
}
