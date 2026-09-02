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
      env: {
        NODE_ENV: 'production',
      },
    },
  ],
};
