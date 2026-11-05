<?php
/** Root-only application initialization. Arguments contain identifiers, never credentials. */
declare(strict_types=1);
ini_set('display_errors', '0');
ini_set('log_errors', '0');

if (PHP_SAPI !== 'cli' || !function_exists('posix_geteuid') || posix_geteuid() !== 0) {
    fwrite(STDERR, "Run configure.php as root through SSM.\n");
    exit(1);
}

function savePrivate(string $path, string $contents, int $mode, string $group = 'root'): void
{
    $temporary = $path . '.new';
    if (file_put_contents($temporary, $contents, LOCK_EX) === false
        || !chmod($temporary, $mode) || !chgrp($temporary, $group)
        || !rename($temporary, $path)) {
        throw new RuntimeException('Private configuration write failed.');
    }
}

try {
    $args = getopt('', ['endpoint:', 'secret-arn:', 'database:', 'region:', 'site-url:']);
    foreach (['endpoint', 'secret-arn', 'database', 'region', 'site-url'] as $required) {
        if (!isset($args[$required]) || !is_string($args[$required])) {
            throw new InvalidArgumentException('Missing argument.');
        }
    }
    $endpoint = $args['endpoint'];
    $database = $args['database'];
    $region = $args['region'];
    $siteUrl = rtrim($args['site-url'], '/');
    if (!preg_match('/^[a-zA-Z0-9.-]+$/D', $endpoint)
        || !preg_match('/^[a-zA-Z][a-zA-Z0-9_]{0,63}$/D', $database)
        || !preg_match('/^[a-z]{2}(?:-[a-z]+)+-[0-9]+$/D', $region)
        || !preg_match('/^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:[a-zA-Z0-9\/_+=.@-]+$/D', $args['secret-arn'])
        || !preg_match('~^https?://[a-z0-9.-]+$~D', $siteUrl)) {
        throw new InvalidArgumentException('Invalid nonsecret configuration argument.');
    }
    $lock = fopen('/etc/infra-lab/configure.lock', 'c');
    if ($lock === false || !flock($lock, LOCK_EX)) {
        throw new RuntimeException('Cannot acquire configuration lock.');
    }
    umask(0077);
    $statePath = '/etc/infra-lab/database.json';
    if (is_file($statePath)) {
        $state = json_decode(file_get_contents($statePath), true, 512, JSON_THROW_ON_ERROR);
        if ($state['endpoint'] !== $endpoint || $state['database'] !== $database) {
            throw new RuntimeException('Existing credentials belong to a different database.');
        }
    } else {
        $state = [
            'endpoint' => $endpoint,
            'database' => $database,
            'username' => 'wordpress_app',
            'password' => bin2hex(random_bytes(32)),
            'salts' => [],
        ];
        foreach (['AUTH_KEY', 'SECURE_AUTH_KEY', 'LOGGED_IN_KEY', 'NONCE_KEY',
                  'AUTH_SALT', 'SECURE_AUTH_SALT', 'LOGGED_IN_SALT', 'NONCE_SALT'] as $key) {
            $state['salts'][$key] = bin2hex(random_bytes(48));
        }
        savePrivate($statePath, json_encode($state, JSON_THROW_ON_ERROR), 0600);
    }

    // Capture the managed master secret in process memory, never stdout, argv, or a file.
    $process = proc_open([
        '/usr/bin/aws', 'secretsmanager', 'get-secret-value',
        '--region', $region, '--secret-id', $args['secret-arn'], '--output', 'json',
    ], [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['file', '/dev/null', 'w']], $pipes);
    if (!is_resource($process)) {
        throw new RuntimeException('Secret retrieval failed.');
    }
    fclose($pipes[0]);
    $response = stream_get_contents($pipes[1]);
    fclose($pipes[1]);
    if (proc_close($process) !== 0) {
        throw new RuntimeException('Secret retrieval failed.');
    }
    $secretResponse = json_decode($response, true, 512, JSON_THROW_ON_ERROR);
    $master = json_decode($secretResponse['SecretString'], true, 512, JSON_THROW_ON_ERROR);
    unset($response, $secretResponse);
    $pdoOptions = [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT => 10,
        PDO::MYSQL_ATTR_SSL_CA => '/etc/infra-lab/global-bundle.pem',
        PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => true,
    ];
    $pdo = new PDO("mysql:host={$endpoint};port=3306;charset=utf8mb4", $master['username'], $master['password'], $pdoOptions);
    unset($master);
    $user = $pdo->quote($state['username']) . "@'%'";
    $password = $pdo->quote($state['password']);
    $pdo->exec("CREATE USER IF NOT EXISTS {$user} IDENTIFIED BY {$password} REQUIRE SSL");
    $pdo->exec("ALTER USER {$user} IDENTIFIED BY {$password} REQUIRE SSL");
    $pdo->exec("GRANT ALL PRIVILEGES ON `{$database}`.* TO {$user}");
    unset($password, $pdo);
    // Confirm that WordPress uses only its restricted account, not the RDS master.
    $appConnection = new PDO("mysql:host={$endpoint};port=3306;dbname={$database};charset=utf8mb4", $state['username'], $state['password'], $pdoOptions);
    $appConnection->query('SELECT 1');
    unset($appConnection);

    $config = "<?php\n// Generated locally; root-owned and never in the public web root.\n";
    foreach ([
        'DB_NAME' => $database,
        'DB_USER' => $state['username'],
        'DB_PASSWORD' => $state['password'],
        'DB_HOST' => $endpoint,
        'DB_CHARSET' => 'utf8mb4',
        'DB_COLLATE' => '',
        'WP_HOME' => $siteUrl,
        'WP_SITEURL' => $siteUrl,
    ] + $state['salts'] as $key => $value) {
        $config .= 'define(' . var_export($key, true) . ', ' . var_export($value, true) . ");\n";
    }
    $config .= <<<'CONFIG'

define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', true);
define('WP_DEBUG', false);
$table_prefix = 'wp_';
// The instance accepts HTTP only from the ALB security group, so trust its header.
if (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https') {
    $_SERVER['HTTPS'] = 'on';
    $_SERVER['SERVER_PORT'] = '443';
}
if (!defined('ABSPATH')) {
    define('ABSPATH', '/opt/infra-lab/repository/course/infra/labs/aws/wordpress/app/public/');
}
if (!defined('INFRA_LAB_READINESS')) {
    require_once ABSPATH . 'wp-settings.php';
}
CONFIG;
    savePrivate('/etc/infra-lab/wp-config.php', $config . "\n", 0640, 'apache');
    // Apache sees this only after successful DB connection and atomic config creation.
    savePrivate('/etc/infra-lab/configured', "configured\n", 0644, 'apache');
    fwrite(STDOUT, "WordPress database configured. Open the site to complete the web installer.\n");
} catch (Throwable $error) {
    // Exception text/stack traces may contain SQL, credentials or secret responses.
    fwrite(STDERR, "Configuration failed. Check arguments, SSM role propagation, database availability and root-only local configuration; credentials were not logged.\n");
    exit(1);
}
