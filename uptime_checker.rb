#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'time'

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
  def initialize
    @sites = []
    load_sites
  end

  def add_site
    puts "\nAdd new site to monitor"
    puts "------------------------"
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
      puts "\nSite added successfully!"
      puts "URL: #{url}"
      puts "Checking every #{interval} seconds"
      puts "Will run command after #{threshold} failures"
      puts "Command: #{command || 'None'}"
    rescue URI::InvalidURIError
      puts "\nError: Invalid URL format. Make sure to include http:// or https://"
    end
  end

  def list_sites
    if @sites.empty?
      puts "\nNo sites configured yet. Use 'add' to monitor a site."
      return
    end

    puts "\nMonitored Sites"
    puts "--------------"
    @sites.each_with_index do |site, index|
      puts "\n#{index + 1}. #{site.url}"
      puts "   Check interval: #{site.interval} seconds"
      puts "   Failure threshold: #{site.threshold}"
      puts "   Current failures: #{site.failures}"
      puts "   Command: #{site.command || 'None'}"
      puts "   Last checked: #{site.last_checked || 'Never'}"
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
      puts "\nRemoved: #{removed.url}"
    else
      puts "\nInvalid site number"
    end
  end

  def start_monitoring
    puts "\nStarting monitoring... Press Ctrl+C to stop"
    puts "----------------------------------------"

    loop do
      @sites.each do |site|
        check_site(site) if should_check?(site)
      end
      sleep 1
    end
  rescue Interrupt
    puts "\nStopping monitoring..."
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
    handle_failure(site)
  end

  def handle_success(site)
    if site.failures > 0
      puts "#{site.url} is back UP"
    end
    site.failures = 0
    site.command_executed = false
    save_sites
  end

  def handle_failure(site)
    site.failures += 1
    puts "#{site.url} is DOWN (Failure #{site.failures}/#{site.threshold})"

    if site.failures >= site.threshold && !site.command_executed && site.command
      puts "Running command: #{site.command}"
      system(site.command)
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
      site.failures = data['failures']
      site.last_checked = data['last_checked']
      site.command_executed = data['command_executed']
      site
    end
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