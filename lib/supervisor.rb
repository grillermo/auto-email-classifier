# frozen_string_literal: true

class Supervisor
  def initialize
    @children = {}
    @threads = []
    @shutting_down = false
  end

  def run(process_setup = nil, &block)
    process_setup ||= block
    raise ArgumentError, "run requires a proc or block that registers processes" unless process_setup.respond_to?(:call)

    trap_signals
    process_setup.call(method(:start_process))
    monitor_children
  ensure
    @shutting_down = true
    shutdown_children
  end

  private

  def start_process(name, command, chdir:)
    out_read, out_write = IO.pipe

    pid = Process.spawn(*command, chdir: chdir, out: out_write, err: out_write)
    out_write.close

    @children[name] = pid
    @threads << Thread.new do
      out_read.each_line do |line|
        puts "[#{name}] #{line.rstrip}"
      end
    ensure
      out_read.close
    end

    puts "[supervisor] started #{name} (pid=#{pid})"
  end

  def monitor_children
    loop do
      pid, status = Process.wait2
      name = @children.key(pid)
      next unless name

      puts "[supervisor] process #{name} exited with status #{status.exitstatus || status.termsig}"
      @children.delete(name)

      if @shutting_down
        break if @children.empty?
        next
      end

      @shutting_down = true
      shutdown_children
      exit(status.exitstatus || 1)
    rescue Errno::ECHILD
      break
    end

    @threads.each(&:join)
  end

  def trap_signals
    %w[INT TERM].each do |signal|
      Signal.trap(signal) do
        @shutting_down = true
        shutdown_children
      end
    end
  end

  def shutdown_children
    @children.each_value do |pid|
      Process.kill("TERM", pid)
    rescue Errno::ESRCH
      nil
    end

    remaining = @children.values.dup
    deadline = Time.now + 10

    until remaining.empty? || Time.now >= deadline
      remaining.reject! do |pid|
        waited = Process.waitpid(pid, Process::WNOHANG)
        !waited.nil?
      rescue Errno::ECHILD
        true
      rescue Errno::ESRCH
        true
      rescue StandardError
        false
      end

      sleep 0.2 unless remaining.empty?
    end

    remaining.each do |pid|
      Process.kill("KILL", pid)
    rescue Errno::ESRCH
      nil
    end

    remaining.each do |pid|
      Process.wait(pid)
    rescue Errno::ECHILD
      nil
    end
  end
end
