require 'digest/md5'

module Amqpop
  class AuthFile

    def initialize
      @hosts = {}
      load_available_files
    end

    def lookup(match_host, match_user = "")
      host = @hosts[match_host]
      return nil if host.nil?
      return nil if host.keys.empty?

      match_user = host.keys.first if match_user.to_s == ""
      pass = host[match_user]
      return nil if pass.to_s == ""

      {:host => match_host, :username => match_user, :password => pass}
    end

    private

      def load_available_files
        ["~/.amqpop_auth"].each do |f|
          f = File.expand_path(f)
          load_file(f)
        end
      end

      def load_file(file)
        if File.exist?(file)
          if world_readable?(file) || world_writable?(file)
            STDERR.puts "WARNING: Auth file: #{file} has unsafe permissions, not loaded"
            return false
          end
          parse_file(file)
        end
      end

      def parse_file(file)
        File.readlines(file).each do |line|
          host, user, pass = line.split(/\s+/)
          if host.to_s == "" || user.to_s == "" || pass.to_s == ""
            STDERR.pust "WARNING: Auth file: #{file} has invalid line, skipped that line"
            return false
          end

          @hosts[host] ||= {}
          @hosts[host][user] = pass
        end
      end

      def world_writable?(file)
        world_write_perms = 0000002
        (File.stat(file).mode & world_write_perms) != 0
      end

      def world_readable?(file)
        world_read_perms = 0000004
        (File.stat(file).mode & world_read_perms) != 0
      end

  end
end
