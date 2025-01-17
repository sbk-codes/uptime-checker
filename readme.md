# Website Uptime Checker

A Ruby script that monitors website uptime and executes commands when sites are down. Perfect for monitoring Heroku apps or any web applications that need automatic recovery actions.

## Features

- Monitor multiple websites simultaneously
- Customizable check intervals per site
- Configurable failure thresholds before taking action
- Automatic command execution (e.g., Heroku app restart)
- Timestamp-based logging to both console and files
- Persistent storage of monitored sites
- Daily log rotation

## Prerequisites

- Ruby (version 2.0 or higher)
- Basic knowledge of terminal/command line
- Heroku or BLD CLI (if monitoring Heroku/BLD apps)

## Installation

1. Download the script:
```bash
git clone https://github.com/sbk-codes/uptime-checker.git
```

2. Make the script executable:
```bash
chmod +x uptime_checker.rb
```

## Usage

1. Start the script:
```bash
ruby uptime_checker.rb
```

2. Available commands:
   - `add`: Add a new site to monitor
   - `list`: Show all monitored sites
   - `remove`: Remove a site from monitoring
   - `start`: Begin monitoring all sites
   - `exit`: Quit the program

### Adding a Site

When adding a site, you'll be prompted for:

1. URL to monitor
   - Must include protocol (http:// or https://)
   - Example: `https://myapp.herokuapp.com`

2. Check interval (in seconds)
   - How often to check the site
   - Default: 5 seconds
   - Example: `10`

3. Failure threshold
   - Number of consecutive failures before executing command
   - Default: 3
   - Example: `3`

4. Command to execute
   - Command to run when site is down
   - Example for Heroku: `heroku ps:restart -a myapp`
   - Example for Build: `bld ps:restart --app=myapp`
   - Leave empty for no action

Example:
```
Enter command: add

Add new site to monitor
------------------------
Enter URL (e.g., https://example.com): https://myapp.herokuapp.com
Check interval in seconds (default: 5): 10
Failure threshold before running command (default: 3): 3
Command to run when down: heroku ps:restart --app=myapp
```

### Monitoring Behavior

- Sites are checked at their specified intervals
- When a site fails:
  1. Failure count increases
  2. When failure count reaches threshold:
     - Specified command is executed
     - Failure count resets to 0
  3. If site remains down:
     - Count begins again from 0
     - Command will execute again when threshold is reached
- When a site recovers:
  - Failure count resets to 0
  - Status is logged as UP

### Logs

Logs are stored in the `logs` directory:
- Format: `uptime_YYYYMMDD.log`
- New log file created daily
- Contains timestamps, status changes, and command executions

Example log entry:
```
2025-01-17 08:33:20 - https://myapp.herokuapp.com is DOWN (Failure 3/3)
2025-01-17 08:33:20 - Running command: heroku ps:restart --app=myapp
2025-01-17 08:33:25 - Command executed successfully
2025-01-17 08:33:25 - Reset failure count to 0 after command execution
```

### Data Persistence

- Site configurations are stored in `sites.json`
- Failures reset to 0 when script restarts
- Site list persists between runs

## Troubleshooting

1. If the script fails to connect:
   - Check if URL is accessible from your machine
   - Verify network connectivity
   - Ensure URL includes http:// or https://

2. If commands don't execute:
   - Check command permissions
   - Verify command works when run manually
   - Ensure required CLI tools are installed

## Notes

- The script must be running to monitor sites
- Use screen or tmux for persistent monitoring
- Consider running as a service for production use
- Logs are automatically rotated daily

## Contributing

Feel free to open issues or submit pull requests for improvements.

## License

MIT License - feel free to use and modify as needed.