#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

PROJECT_ROOT = File.expand_path("..", __dir__)
RULES_EDITOR_ROOT = File.join(PROJECT_ROOT, "rules_editor")

options = { dry_run: false }

begin
  OptionParser.new do |parser|
    parser.banner = "Usage: bundle exec ruby mail_listener/listener.rb [--dry-run]"
    parser.on("--dry-run", "Print what matching rules would do without applying them") do
      options[:dry_run] = true
    end
  end.parse!(ARGV)
rescue OptionParser::ParseError => e
  abort "[listener] #{e.message}"
end

abort "[listener] Unknown arguments: #{ARGV.join(' ')}" if ARGV.any?

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.1")
  abort "[listener] Ruby #{RUBY_VERSION} detected. Use Ruby 3.4+."
end

begin
  require File.join(RULES_EDITOR_ROOT, "config", "environment")
rescue StandardError => e
  abort "[listener] Failed to load Rails environment: #{e.message}. Run bundle install in #{RULES_EDITOR_ROOT}."
end

module MailListener
  class Runner
    def initialize(dry_run: false)
      @shutdown = false
      @dry_run = dry_run
      @interval = ENV.fetch("GMAIL_POLL_INTERVAL_SECONDS", "60").to_i
      @interval = 60 if @interval <= 0
    end

    def run
      install_signal_handlers
      puts "[listener] started (interval=#{@interval}s, mode=#{dry_run? ? "dry-run" : "live"})"

      until @shutdown
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        process_cycle
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

        sleep_for = @interval - elapsed
        break if @shutdown

        sleep([sleep_for, 1].max)
      end

      puts "[listener] stopped"
    end

    private

    def dry_run?
      @dry_run
    end

    def process_cycle
      MailListener::CycleProcessor.new(dry_run: dry_run?).process!
    end

    def install_signal_handlers
      %w[INT TERM].each do |signal|
        Signal.trap(signal) { @shutdown = true }
      end
    end
  end
end

MailListener::Runner.new(dry_run: options[:dry_run]).run
