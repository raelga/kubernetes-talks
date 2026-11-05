<?php
declare(strict_types=1);
header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-store');
$filesReady = is_file(__DIR__ . '/wp-settings.php') && is_file(__DIR__ . '/wp-admin/install.php');
http_response_code($filesReady ? 200 : 503);
?>
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>WordPress web stage</title></head>
<body>
<h1>WordPress web stage</h1>
<p>Apache and PHP are running. WordPress application files are <?= $filesReady ? 'ready' : 'not ready' ?>.</p>
<p>The database has not been configured. This is not an installed WordPress site.</p>
<p>Enable the private MySQL database, then run the explicit SSM configuration command from the README.</p>
<p><a href="/health.php">Web liveness</a> · <a href="/readiness.php">Application readiness (503 until configured)</a></p>
</body>
</html>
