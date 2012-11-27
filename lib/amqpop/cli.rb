require 'amqpop/amqpop'
require 'amqpop/trollop'
require 'amqpop/lock_file'
require 'amqpop/auth_file'
require 'amqpop/message'
require 'eventmachine'
require 'amqp'

module Amqpop

  class CLI

    def self.start
      self.new.start
    end

    def initialize
      STDOUT.sync = true
      options
      @lock = LockFile.new(options)
      @lock.acquire!
      @auth = AuthFile.new
    end

    def start
      begin
        EventMachine.threadpool_size = options[:num_children]
        EventMachine.run do
          Signal.trap("INT")  { shutdown }
          Signal.trap("TERM") { shutdown }

          vputs "Running #{AMQP::VERSION} version of the AMQP gem."
          vputs "Connecting to AMQP broker on #{connection_params[:host]} as #{connection_params[:username]}."
          AMQP.connect(connection_params) do |connection|
            AMQP::Channel.new(connection) do |channel|

              if options[:wait] == 0
                vputs "No timeout set, process will stay running"
              else
                vputs "Timeout of #{options[:wait]} seconds set"
              end

              queue = get_queue(channel)

              queue.once_declared do
                vputs "Connected to queue: #{queue.name}"
                vputs "Ack mode: #{Amqpop.require_ack? ? 'explicit' : 'auto'}"
              end
              
              bind_queue(queue)

              queue.subscribe(:confirm => proc{ wait_exit_timer }, :ack => Amqpop.require_ack?) do |meta, payload|
                cancel_wait_exit_timer
                m = Message.new(payload, meta)
                vputs "Received a message: #{payload}. Executing..."
                EventMachine.defer(m.command_proc, m.callback_proc)
                wait_exit_timer
              end

            end
          end
        end
      rescue => e
        eputs "ERROR: #{e.class} - #{e.message}"
        exit 2
      end
    end

    private

      def shutdown
        EventMachine.stop
        @lock.release!
        exit 0
      end

      def connection_params
        return @connection_params if defined?(@connection_params)

        params = {:host => options[:host], :username => options[:user], :password => options[:pass]}

        if options[:host] != "localhost" && options[:user] != "guest" && options[:pass] != "guest"
          # Every option was changed from the default, so we don't need to lookup anything
          @connection_params = params
          return @connection_params
        end

        if options[:host] != "localhost" && options[:user] == "guest" && options[:pass] == "guest"
          # They set host, but not user or pass
          creds = @auth.lookup(options[:host], options[:user])
          creds = @auth.lookup(options[:host]) if creds.nil?

          @connection_params = (creds.nil?) ? params : creds

          return @connection_params
        end

        if options[:host] != "localhost" && options[:user] != "guest" && options[:pass] == "guest"
          # They set host and user, but not pass
          creds = @auth.lookup(options[:host], options[:user])
          @connection_params = (creds.nil?) ? params : creds

          return @connection_params
        end

        @connection_params = params

      end

      def cancel_wait_exit_timer
        @wait_timer.cancel if defined?(@wait_timer)
      end

      def wait_exit_timer
        return if options[:wait] == 0
        cancel_wait_exit_timer
        @wait_timer = EventMachine::Timer.new(options[:wait]) do
          vputs "Timeout of #{options[:wait]} seconds expired, exiting"
          shutdown
        end
      end

      def bind_queue(queue)
        if options[:exchange][:name] == ""
          vputs "Binding queue to default exchange implicitly, with routing key '#{queue.name}'"
        else
          vputs "Binding queue to exchange: #{options[:exchange][:name]}, with routing key '#{options[:exchange][:routing_key]}'"
          queue.bind(options[:exchange][:name], :routing_key => options[:exchange][:routing_key])
        end
      end

      def get_queue(channel)
        if Amqpop.temp_queue?
          channel.queue('', :auto_delete => true, :durable => false, :exclusive => true)
        else
          channel.queue(options[:queue_name], :auto_delete => false, :durable => true)
        end
      end

      def eputs(msg)
        Amqpop.eputs msg
      end

      def vputs(msg)
        Amqpop.vputs msg
      end

      def options
        return Amqpop.options unless Amqpop.options.nil?
        @options = Trollop::options do
          version "amqpop 0.0.1 (c) 2012 Chris Cherry"
          banner <<-EOS
Command line tool for consuming messages off of an AMQP queue and dispatching them to a user specified command.

Usage:
       amqpop [options] -- <child-command>

[options] are:

EOS
          opt :host, "AMQP host", :type => :string, :short => "-h", :default => 'localhost'
          opt :user, "AMQP user", :type => :string, :short => "-u", :default => 'guest'
          opt :pass, "AMQP password", :type => :string, :short => "-p", :default => 'guest'
          opt :num_children, "Number of child message processing commands that can be executed in parallel", :short => "-n", :default => 1
          opt :queue_name, "Name of the queue on the to connect to, unique if not provided", :type => :string, :default => ''
          opt :queue_durable, "Is the queue persistant", :default => true
          opt :queue_auto_delete, "Does the queue remove itself", :default => false
          opt :exchange, "Exchange to bind the queue to. Format [name]:<routing_key>, example: logs or weather:usa.*", :type => :string, :short => "-x", :default => ''

          opt :wait, "Amount of time in seconds to wait for more messages to show up. Waits forever if 0", :default => 30
          opt :verbose, "Verbose logging", :short => :none
          opt :help, "Show this help message", :short => :none
          stop_on "--"
        end

        # Break exchange into hash of its parts
        ename, eroute = @options[:exchange].to_s.split(":")
        @options[:exchange] = {:name => ename.to_s, :routing_key => eroute.to_s}

        # 1 second is too fast, make it a minimum of 2
        @options[:wait] = 2 if @options[:wait] == 1

        # Store child command, or empty array
        dbldash = ARGV.shift
        @options[:child_command] = ARGV.dup
        Amqpop.options = @options
      end

  end
end