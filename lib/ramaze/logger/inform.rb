#          Copyright (c) 2006 Michael Fellinger m.fellinger@gmail.com
# All files in this distribution are subject to the terms of the Ruby license.

module Ramaze

  # This classes responsibility is to provide a simple but powerful way to log
  # the status of Ramaze.
  #
  # It gives you a number of 
  # You can include/extend your objects with it and access its methods.
  # Please note that all methods are private, so you should use them only
  # within your object. The reasoning for making them private is simply
  # to avoid interference inside the controller.
  #
  # In case you want to use it from the outside you can work over the
  # Informer object. This is used for example as the Logger for WEBrick.
  #
  # Inform is a tag-based system, Global.inform_tags holds the tags
  # that are used to filter the messages passed to Inform. The default
  # is to use all tags :debug, :info and :error.
  #
  # You can control what gets logged over this Set.

  class Informer

    # :stdout/'stdout'/$stdout (similar for stdout) or some path to a file
    trait :to => $stdout

    # a Set with any of [ :debug, :info, :error ]
    trait :tags => Set.new([:debug, :info, :error])

    # This is how the final output is arranged.
    trait :format => "[%time] %prefix  %text"
    # parameter for Time.strftime
    trait :timestamp => "%Y-%m-%d %H:%M:%S"

    # prefix for all the Inform#info messages
    trait :prefix_info => 'INFO '

    # prefix for all the Inform#debug messages
    trait :prefix_debug => 'DEBUG'

    # prefix for all the Inform#error messages
    trait :prefix_error => 'ERROR'

    # Should the output to terminal have ANSI colors?
    trait :color => false

    # Which tag should be in what color
    trait :colors => {
      :info  => :green,
      :debug => :yellow,
      :warn  => :red,
      :error => :red,
    }

    # the possible tags, run Informer::rebuild_tags after changes.

    trait :tags => {
      :debug  => lambda{|*m| m.map{|o| o.inspect} },
      :info   => lambda{|*m| m.map{|o| o.to_s}    },
      :warn   => lambda{|*m| m.map{|o| o.to_s}    },
      :error  => lambda do |m|
        break(m) unless m.respond_to?(:exception)
        bt = m.backtrace[0..Global.backtrace_size]
        [ m.inspect ] + bt
      end
    }

    class << self

      # takes the trait[:tags] and generates methods out of them.

      def rebuild_tags
        trait[:tags].each do |tag, block|
          define_method(tag) do |*messages|
            return unless inform_tag?(tag)
            log(tag, block[*messages])
          end

          define_method("#{tag}?") do
            inform_tag?(tag)
          end
        end
      end

      # answers with an instance

      def startup
        @instance ||= self.new
      end

      # closes all open IOs in trait[:to]

      def shutdown
        [ancestral_trait[:to]].flatten.each do |io|
          if io = ancestral_trait[:to] and io.respond_to?(:close)
            Inform.debug("close #{io.inspect}")
            io.close until io.closed?
          end
        end
      end
    end

    def initialize
      self.class.rebuild_tags
    end

    # this simply sends the parameters to #debug

    def <<(*str)
      debug(*str)
    end

    # This uses Global.inform_timestamp or a date in the format of
    #   %Y-%m-%d %H:%M:%S
    #   # => "2007-01-19 21:09:32"

    def timestamp
      mask = ancestral_trait[:timestamp]
      Time.now.strftime(mask || "%Y-%m-%d %H:%M:%S")
    end

    # is the given inform_tag in Global.inform_tags ?

    def inform_tag?(inform_tag)
      ancestral_trait[:tags].keys.include?(inform_tag)
    end

    # the common logging-method, you shouldn't have to call this yourself
    # it takes the prefix and any number of messages.
    #
    # The produced inform-message consists of
    #   [timestamp] prefix  message
    # For the output is anything used that responds to :puts, the default
    # is $stdout in:
    #   Global.inform_to
    # where you can configure it.
    #
    # To log to a file just do
    #   Global.inform_to = File.open('log.txt', 'a+')

    def log tag, *messages
      messages.flatten!

      pipify(ancestral_trait[:to]).each do |do_color, pipe|
        next if pipe.respond_to?(:closed?) and pipe.closed?

        prefix = colorize(tag, ancestral_trait["prefix_#{tag}".to_sym], do_color)

        messages.each do |message|
          pipe.puts(log_interpolate(prefix, message))
        end
      end
    end

    def colorize tag, prefix, do_color
      return prefix unless ancestral_trait[:color] and do_color
      color = ancestral_trait[:colors][tag] ||= :white
      prefix.send(color)
    end

    def log_interpolate prefix, text, timestamp = timestamp
      message = ancestral_trait[:format].dup

      vars = { '%time' => timestamp, '%prefix' => prefix, '%text' => text }
      vars.each{|from, to| message.gsub!(from, to) }

      message
    end

    def pipify *ios
      color, no_color = true, false

      ios.flatten.map do |io|
        case io
        when STDOUT, :stdout, 'stdout'
          [ color, STDOUT ]
        when STDERR, :stderr, 'stderr'
          [ color, STDERR ]
        when IO
          [ no_color, io  ]
        else
          [no_color, File.open(io.to_s, 'ab+')]
        end
      end
    end
  end
end
