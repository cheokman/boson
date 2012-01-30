module Boson
  # Scientist wraps around and redefines an object's method to give it the following features:
  # * Methods can take shell command input with options or receive its normal arguments. See the Commandification
  #   section.
  # * Methods have a slew of global options available. See OptionCommand for an explanation of basic global options.
  #
  # The main methods Scientist provides are redefine_command() for redefining an object's method with a Command object
  # and commandify() for redefining with a hash of method attributes. Note that for an object's method to be redefined correctly,
  # its last argument _must_ expect a hash.
  #
  # === Commandification
  # Take for example this basic method/command with an options definition:
  #   options :level=>:numeric, :verbose=>:boolean
  #   def foo(*args)
  #     args
  #   end
  #
  # When Scientist wraps around foo(), it can take arguments normally or as a shell command:
  #    foo 'one', 'two', :verbose=>true   # normal call
  #    foo 'one two -v'                 # commandline call
  #
  #    Both calls return: ['one', 'two', {:verbose=>true}]
  #
  # Non-string arguments can be passed as well:
  #    foo Object, 'two', :level=>1
  #    foo Object, 'two -l1'
  #
  #    Both calls return: [Object, 'two', {:level=>1}]
  module Scientist
    extend self
    # Handles all Scientist errors.
    class Error < StandardError; end

    attr_accessor :global_options
    @no_option_commands ||= []
    @option_commands ||= {}
    @object_methods = {}

    # Redefines an object's method with a Command of the same name.
    def redefine_command(obj, command)
      cmd_block = redefine_command_block(obj, command)
      @no_option_commands << command if command.options.nil?
      [command.name, command.alias].compact.each {|e|
        obj.instance_eval("class<<self;self;end").send(:define_method, e, cmd_block)
      }
    rescue Error
      $stderr.puts "Error: #{$!.message}"
    end

    # A wrapper around redefine_command that doesn't depend on a Command object. Rather you
    # simply pass a hash of command attributes (see Command.new) or command methods and let OpenStruct mock a command.
    # The only required attribute is :name, though to get any real use you should define :options and
    # :arg_size (default is '*'). Example:
    #   >> def checkit(*args); args; end
    #   => nil
    #   >> Boson::Scientist.commandify(self, :name=>'checkit', :options=>{:verbose=>:boolean, :num=>:numeric})
    #   => ['checkit']
    #   # regular ruby method
    #   >> checkit 'one', 'two', :num=>13, :verbose=>true
    #   => ["one", "two", {:num=>13, :verbose=>true}]
    #   # commandline ruby method
    #   >> checkit 'one two -v -n=13'
    #   => ["one", "two", {:num=>13, :verbose=>true}]
    def commandify(obj, hash)
      raise ArgumentError, ":name required" unless hash[:name]
      hash[:arg_size] ||= '*'
      hash[:has_splat_args?] = true if hash[:arg_size] == '*'
      fake_cmd = OpenStruct.new(hash)
      fake_cmd.option_parser ||= OptionParser.new(fake_cmd.options || {})
      redefine_command(obj, fake_cmd)
    end

    # The actual method which redefines a command's original method
    def redefine_command_block(obj, command)
      object_methods(obj)[command.name] ||= begin
        obj.method(command.name)
      rescue NameError
        raise Error, "No method exists to redefine command '#{command.name}'."
      end
      lambda {|*args|
        Scientist.analyze(obj, command, args) {|args|
          Scientist.object_methods(obj)[command.name].call(*args)
        }
      }
    end

    #:stopdoc:
    def object_methods(obj)
      @object_methods[obj] ||= {}
    end

    def option_command(cmd=@command)
      @option_commands[cmd] ||= OptionCommand.new(cmd)
    end

    def call_original_command(args, &block)
      block.call(args)
    end

    def analyze(obj, command, args, &block)
      @global_options, @command, original_args = {}, command, args.dup
      @args = translate_args(obj, args)
      return run_help_option if @global_options[:help]
      run_pretend_option(@args)
      process_result call_original_command(@args, &block) unless @global_options[:pretend]
    rescue OptionCommand::CommandArgumentError
      run_pretend_option(@args ||= [])
      return if !@global_options[:pretend] && run_verbose_help(option_command, original_args)
      raise unless @global_options[:pretend]
    rescue OptionParser::Error, Error
      raise if Boson.in_shell
      message = @global_options[:verbose] ? "#{$!}\n#{$!.backtrace.inspect}" : $!.message
      $stderr.puts "Error: " + message
    end

    def translate_args(obj, args)
      option_command.modify_args(args)
      @global_options, @current_options, args = option_command.parse(args)
      return if @global_options[:help]
      after_parse

      if @current_options
        option_command.add_default_args(args, obj)
        return args if @no_option_commands.include?(@command)
        args << @current_options
        option_command.check_argument_size(args)
      end
      args
    end

    def after_parse
    end

    def run_verbose_help(option_command, original_args)
      global_opts = option_command.parse_global_options(original_args)
      if global_opts[:help] && global_opts[:verbose]
        @global_options = global_opts
        run_help_option
        return true
      end
      false
    end

    def help_options
      @global_options[:verbose] ? ['--verbose'] : []
    end

    def run_help_option
      Boson.invoke :usage, @command.full_name + " " + help_options.join(' ')
    end

    def run_pretend_option(args)
      if @global_options[:verbose] || @global_options[:pretend]
        puts "Arguments: #{args.inspect}", "Global options: #{@global_options.inspect}"
      end
    end

    def process_result(result)
      result
    end
    #:startdoc:
  end
end
