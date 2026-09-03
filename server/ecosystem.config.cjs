module.exports = {
  apps: [
    {
      name: 'meet6-api',
      cwd: '/var/www/meet6/server',
      script: 'dist/main.js',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '700M',
      min_uptime: '10s',
      max_restarts: 10,
      restart_delay: 2000,
      exp_backoff_restart_delay: 100,
      kill_timeout: 10000,
      listen_timeout: 10000,
      node_args: '--enable-source-maps',
      merge_logs: true,
      out_file: '/var/log/meet6/api-out.log',
      error_file: '/var/log/meet6/api-error.log',
      log_date_format: 'YYYY-MM-DDTHH:mm:ss.SSSZ',
      env: {
        NODE_ENV: 'production',
      },
      env_production: {
        NODE_ENV: 'production',
      },
    },
  ],
};
