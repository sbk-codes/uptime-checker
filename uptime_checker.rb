#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'time'
require 'logger'
require 'fileutils'

class Site
  attr_reader :url, :interval, :threshold, :command
  attr_accessor :failures, :last_checked, :command_executed

  def initialize(url:, interval: 5, threshold: 3, command: nil)
    @url = url
    @interval = interval.to_i
    @threshold = threshold.to_i
    @command = command
    @failures = 0
    @last_checked = nil
    @command_executed = false
  end

  def to_h
    {
      url: url,
      interval: interval,
      threshold: threshold,
      command: command,
      failures: failures,
      last_checked: last_checked,
      command_executed: command_executed
    }
  end
end

class UptimeChecker
  LOG_DIR = 'logs'

  def initialize
    @sites = []
    setup_logger
    load_sites
  end

  def setup_logger
    FileUtils.mkdir_p(LOG_DIR)
    log_file = File.join(LOG_DIR, "uptime_#{Time.now.strftime('%Y%m%d')}.log")
    @logger = Logger.new(log_file)
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} #{severity}: #{msg}\n"
    end
  end

  def log_message(message, level = :info)
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    puts "#{timestamp} - #{message}"
    @logger.send(level, message)
  end

  def add_site
    log_message("\nAdd new site to monitor")
    log_message("------------------------")
    print "Enter URL (e.g., https://example.com): "
    url = gets.chomp

    print "Check interval in seconds (default: 5): "
    interval = gets.chomp
    interval = 5 if interval.empty?

    print "Failure threshold before running command (default: 3): "
    threshold = gets.chomp
    threshold = 3 if threshold.empty?

    print "Command to run when down (e.g., heroku restart -a myapp): "
    command = gets.chomp
    command = nil if command.empty?

    begin
      site = Site.new(
        url: url,
        interval: interval,
        threshold: threshold,
        command: command
      )
      @sites << site
      save_sites

      log_message("\nSite added successfully!")
      log_message("URL: #{url}")
      log_message("Checking every #{interval} seconds")
      log_message("Will run command after #{threshold} failures")
      log_message("Command: #{command || 'None'}")
    rescue URI::InvalidURIError
      log_message("\nError: Invalid URL format. Make sure to include http:// or https://", :error)
    end
  end

  def list_sites
    if @sites.empty?
      log_message("\nNo sites configured yet. Use 'add' to monitor a site.")
      return
    end

    log_message("\nMonitored Sites")
    log_message("--------------")
    @sites.each_with_index do |site, index|
      log_message("\n#{index + 1}. #{site.url}")
      log_message("   Check interval: #{site.interval} seconds")
      log_message("   Failure threshold: #{site.threshold}")
      log_message("   Current failures: #{site.failures}")
      log_message("   Command: #{site.command || 'None'}")
      log_message("   Last checked: #{site.last_checked || 'Never'}")
    end
  end

  def remove_site
    list_sites
    return if @sites.empty?

    print "\nEnter the number of the site to remove: "
    index = gets.chomp.to_i - 1

    if index >= 0 && index < @sites.length
      removed = @sites.delete_at(index)
      save_sites
      log_message("\nRemoved: #{removed.url}")
    else
      log_message("\nInvalid site number", :error)
    end
  end

  def start_monitoring
    log_message("\nStarting monitoring... Press Ctrl+C to stop")
    log_message("----------------------------------------")

    loop do
      @sites.each do |site|
        check_site(site) if should_check?(site)
      end
      sleep 1
    end
  rescue Interrupt
    log_message("\nStopping monitoring...")
    save_sites
  end

  private

  def should_check?(site)
    return true if site.last_checked.nil?
    Time.now - Time.parse(site.last_checked) >= site.interval
  end

  def check_site(site)
    uri = URI.parse(site.url)
    response = Net::HTTP.get_response(uri)
    site.last_checked = Time.now.to_s

    if response.is_a?(Net::HTTPSuccess)
      handle_success(site)
    else
      handle_failure(site)
    end
  rescue StandardError => e
    log_message("Error checking #{site.url}: #{e.message}", :error)
    handle_failure(site)
  end

  def handle_success(site)
    if site.failures > 0
      log_message("#{site.url} is back UP")
    end
    site.failures = 0
    site.command_executed = false
    save_sites
  end

  def handle_failure(site)
    site.failures += 1
    log_message("#{site.url} is DOWN (Failure #{site.failures}/#{site.threshold})")

    # Reset command_executed flag when failures reach threshold again
    if site.failures >= site.threshold && site.command_executed
      site.command_executed = false
    end

    if site.failures >= site.threshold && !site.command_executed && site.command
      log_message("Running command: #{site.command}")
      execution_result = system(site.command)
      if execution_result
        log_message("Command executed successfully")
        # Reset failure count after successful command execution
        site.failures = 0
        log_message("Reset failure count to 0 after command execution")
      else
        log_message("Command execution failed", :error)
      end
      site.command_executed = true
    end
    save_sites
  end

  def save_sites
    File.write('sites.json', JSON.pretty_generate(@sites.map(&:to_h)))
  end

  def load_sites
    return unless File.exist?('sites.json')
    
    sites_data = JSON.parse(File.read('sites.json'))
    @sites = sites_data.map do |data|
      site = Site.new(
        url: data['url'],
        interval: data['interval'],
        threshold: data['threshold'],
        command: data['command']
      )
      # Reset failures and command_executed state on script startup
      site.failures = 0
      site.last_checked = nil
      site.command_executed = false
      site
    end
    log_message("Loaded #{@sites.length} sites from configuration")
    log_message("Reset all failure counts to 0 on startup")
  end
end

# Main program loop
checker = UptimeChecker.new

puts "Website Uptime Checker"
puts "Available commands: add, list, remove, start, exit"

loop do
  print "\nEnter command: "
  case gets.chomp.downcase
  when 'add'
    checker.add_site
  when 'list'
    checker.list_sites
  when 'remove'
    checker.remove_site
  when 'start'
    checker.start_monitoring
  when 'exit'
    puts "Goodbye!"
    break
  else
    puts "Unknown command. Available commands: add, list, remove, start, exit"
  end
end