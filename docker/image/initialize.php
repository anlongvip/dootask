<?php

// Container bootstrap only; configuration and credentials never enter the image.
if (($argv[1] ?? '') === 'credentials') {
    require '/var/www/vendor/autoload.php';
    $app = require '/var/www/bootstrap/app.php';
    $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
    $file = '/var/www/storage/app/install-credentials.txt';
    if (!is_file($file)) {
        $password = bin2hex(random_bytes(16));
        $salt = bin2hex(random_bytes(3));
        $user = Illuminate\Support\Facades\DB::table('users')->where('userid', 1)->first();
        if (!$user) {
            throw new RuntimeException('Initial administrator is missing');
        }
        Illuminate\Support\Facades\DB::table('users')->where('userid', 1)->update([
            'encrypt' => $salt,
            'password' => md5(md5($password) . $salt),
        ]);
        // Disable the seeded test account rather than leaving a known password active.
        Illuminate\Support\Facades\DB::table('users')->where('email', 'test@dootask.com')->update([
            'encrypt' => $salt,
            'password' => md5(md5(bin2hex(random_bytes(32))) . $salt),
        ]);
        file_put_contents($file, "Email: {$user->email}\nPassword: {$password}\n");
        chmod($file, 0600);
    }
    exit;
}

if (!is_file('/var/www/.env')) {
    $template = file_get_contents('/opt/dootask/.env.docker');
    $values = [
        'APP_ENV' => 'production',
        'APP_DEBUG' => 'false',
        'ONLINE_UPDATE' => 'false',
        'APP_KEY' => 'base64:' . base64_encode(random_bytes(32)),
        'APP_ID' => getenv('APP_ID') ?: bin2hex(random_bytes(3)),
        'DOOTASK_PROJECT' => getenv('DOOTASK_PROJECT') ?: 'dootask',
        'VOLUME_PREFIX' => getenv('VOLUME_PREFIX') ?: 'dootask',
        'APP_IPPR' => '10.' . random_int(50, 100) . '.' . random_int(100, 200),
        'APP_URL' => getenv('APP_URL') ?: 'http://localhost:2222',
        'APP_PORT' => getenv('APP_PORT') ?: '2222',
        'DB_HOST' => 'mariadb',
        'DB_PASSWORD' => getenv('DB_PASSWORD'),
        'DB_ROOT_PASSWORD' => getenv('DB_ROOT_PASSWORD'),
        'LARAVELS_REACTOR_NUM' => '1',
        'LARAVELS_WORKER_NUM' => '2',
        'LARAVELS_TASK_WORKER_NUM' => '1',
    ];
    foreach (['DB_PASSWORD', 'DB_ROOT_PASSWORD'] as $required) {
        if (!$values[$required] || strlen($values[$required]) < 16) {
            throw new RuntimeException("{$required} must contain at least 16 characters");
        }
    }
    foreach ($values as $key => $value) {
        // Quoted dotenv values, with no possibility of injecting extra lines.
        if (strpbrk($value, "\r\n") !== false) {
            throw new RuntimeException("Invalid multiline value for {$key}");
        }
        $line = $key . '="' . str_replace(['\\', '"', '$'], ['\\\\', '\\"', '\\$'], $value) . '"';
        if (preg_match('/^' . $key . '=/m', $template)) {
            $template = preg_replace_callback('/^' . $key . '=.*$/m', static fn () => $line, $template);
        } else {
            $template .= "\n{$line}\n";
        }
    }
    file_put_contents('/var/www/.env', $template);
    chmod('/var/www/.env', 0600);
}
