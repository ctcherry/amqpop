amqpop
======

Tool for dispatching a child command for each message consumed from an AMQP
queue.


Benefits
--------

Designed for situations where you need to consume and act on messages from an
AMQP queue without a long running process.


Example
-------

    amqpop -h rabbit.domain.com -u user -n 2 -x logs -w 10 -- /usr/bin/ruby log_processor.rb

This command would do the following:

- Make sure only 1 instance of this amqpop command is running by using a
lock/pid file keyed based on the arguments of the command
- Connect to the AMQP server `rabbit.domain.com` as `user` with password looked
up from the auth file ~/.amqpop_auth
- Attach a unique, non durable queue to the exchange named logs
- Pass the message payload in as STDIN to `/usr/bin/ruby log_processor.rb`
- Run up to 2 parallel processes of `/usr/bin/ruby log_processor.rb`
- Once the queue has been exhausted of messages, wait for another message for 10
seconds, if one shows up inside of that time, process it immediately, and then
wait for another 10 seconds and repeat, otherwise terminate.


Usage
-----

    amqpop [options] -- <child-command>

    [options] are:
    -h <s>:  AMQP host (default: localhost)
    -u <s>:  AMQP user (default: guest)
    -p <s>:  AMQP password (default: guest)
    -n <i>:  Number of child message processing commands that can be executed in
             parallel (default: 1)
    -q <s>:  Name of the queue on the to connect to, unique if not provided
             (default: )
        -e:  Is the queue persistent (default: true)
        -a:  Does the queue remove itself
    -x <s>:  Exchange to bind the queue to. Format [name]:<routing>, example:
             logs or weather:usa.* (default: )
    -w <i>:  Amount of time in seconds to wait for more messages to show up.
             Waits forever if 0 (default: 30)

    --verbose, -v:   Verbose logging
    --version, -r:   Print version and exit
       --help, -l:   Show this message


Auth File
---------

You can put a file at ~/.amqpop_auth which is used to intelligently look up
login credentials when calling amqpop. No more sensative information in the
process list or in your history! Use one entry per line, in the format:

    host    user    pass

Example:

    192.168.1.1    consumer    1Consumer2
    192.168.1.1    other       XYother$Z
    rabbithost.domain.com    publisher_user    98pubPass234

The amount and kind of whitespace between host, user and pass don't matter, just
don't use newlines.

Note: The auth file must have world readable and writable disabled (so 660 or
600 are ok)


Tested On
---------
* OSX 10.8.2, 10.7.5
* Ruby 1.9.3-p327, 1.8.7-p358
* RabbitMQ 2.8.7
  * on Erlang R14A, Debian 6.0, kernel 2.6.32-5-686
  * on Erlang R14B04, RedHat EL5, kernel 2.6.18-238.9.1.el5xen


Acknowledgements
----------------

Thank you to William Morgan and the contributors of Trollop
(http://trollop.rubyforge.org/)

