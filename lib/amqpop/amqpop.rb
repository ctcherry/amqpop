module Amqpop

	class << self
		attr_accessor :options
	end

	self.options = nil

	def self.require_ack?
    return nil if options.nil?
	  !temp_queue?
	end

	def self.temp_queue?
		return nil if options.nil?
	  options[:queue_name] == ""
	end

  def self.eputs(msg)
    STDERR.puts msg
  end

  def self.vputs(msg)
    eputs "> #{msg}" if verbose?
  end

  def self.verbose?
    return nil if options.nil?
    options[:verbose]
  end

end