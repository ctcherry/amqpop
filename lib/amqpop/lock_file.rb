require 'digest/md5'

module Amqpop
  class LockFile

  	def initialize(options)
  		@options = options.dup
  	end

    def aquire!
      if exist?
        pid = File.read(file_path).strip
        if pid_alive?(pid)
          aquire_failed(pid)
          return false
        else
          clean_file
        end
      end
      create_lock
      return true
    end

    def release!
      clean_file
    end

    private

      def aquire_failed(pid)
        STDERR.puts "ERROR: amqpop is already running with the provided options with PID #{pid}"
        exit 1
      end

      def file_path
        File.join('/tmp', name)
      end

      def name
        "amqpop.#{option_hash}.pid"
      end

      def option_hash
        ks = @options.keys.sort
        buffer = []
        ks.each do |k|
          buffer << k
          buffer << @options[k].to_s
        end

        Digest::MD5.hexdigest(buffer.join)
      end

      def exist?
        File.exist? file_path
      end

      def clean_file
        File.unlink file_path if exist?
      end

      def create_lock
        return false if exist?
        File.open(file_path, "w") { |f| f.write Process.pid }
        return true
      end

      def pid_alive?(pid)
        begin
          Process.getpgid(pid.to_i)
          return true
        rescue Errno::ESRCH
          return false
        end
      end

  end
end