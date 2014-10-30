module Amqpop
  class Message

    def initialize(payload, meta)
      @meta = meta
      @payload = payload
    end

    def ack
      @meta.ack
    end

    def requeue
      @meta.reject(:requeue => true)
    end

    def discard
      @meta.reject(:requeue => false)
    end

    def command_proc
      if child_command_set?
        process_command_proc
      else
        plain_command_proc
      end
    end

    def callback_proc
      if child_command_set?
        process_callback_proc
      else
        plain_callback_proc
      end
    end

    private

      def options
        Amqpop.options
      end

      def vputs(msg)
        Amqpop.vputs msg
      end

      def child_command_set?
        options[:child_command].length != 0
      end

      def child_command_str
        options[:child_command].join(' ')
      end

      def plain_command_proc
				proc do
          puts @payload
        end
  		end

      def plain_callback_proc
        if Amqpop.require_ack?
          return proc do
            self.ack
          end
        else
          return proc{}
        end
      end

      def process_command_proc
        proc do
          retry_limit = 3
          retried = 0
          vputs "Running process: `#{child_command_str}`"
          begin
            IO.popen(child_command_str, "r+") { |f|
              f.puts @payload
              f.close_write
              r = f.gets
              vputs r unless r == ''
            }
            ret = $?
          rescue => e
            vputs "Exception Running process: `#{child_command_str}`"
            vputs "  #{e.class} - #{e.message}"
            retried += 1
            if retried > retry_limit
              vputs "Out of retries, aborting"
              ret = 255
            else
              vputs "Retry (#{retried}/#{retry_limit}) Waiting #{retried} and trying again"
              sleep retried
              retry
            end
          end
          ret
        end
      end

      def process_callback_proc
  			
        if Amqpop.require_ack?

					return proc do |exit_status|
            if exit_status == 0
              vputs "Process terminated successfully. Acking message."
              self.ack
            else
              vputs "Process terminated with non-zero exit status #{exit_status}. Requeuing message."
              self.requeue
            end
          end 

        end

        return proc do |exit_status|
          if exit_status == 0
            vputs "Process terminated successfully."
          else
            vputs "Process terminated with non-zero exit status #{exit_status}."
          end
        end

      end

  end
end
