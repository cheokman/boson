module Boson
  class BinRunner < Runner
    class <<self
      def init(options={})
        super
        if @command = options[:discover][/\w+/]
          discover_command(@command, options)
        end
      end

      def discover_command(command, options)
        libraries_to_load.find {|e|
          if (lib = Library.quick_load(e, options)) && lib.commands.include?(command)
            lib.load_dependencies
            lib.after_load(options)
          end
          Boson.main_object.respond_to? command
        }
      end

      def full_discover_command(command, options)
        libraries_to_load.find {|e|
          Library.load [e], options
          Boson.main_object.respond_to? command
        }
      end

      def libraries_to_load
        boson_libraries + all_libraries.partition {|e| e =~ /#{@command}/ }.flatten
      end

      def start(args=ARGV)
        return print_usage if args.empty?
        if init :discover=>args[0], :verbose=>true
          if args[0].include?('.')
            meth1, meth2 = args.shift.split('.', 2)
            dispatcher = Boson.invoke(meth1)
            args.unshift meth2
          else
            dispatcher = Boson.main_object
          end
          output = dispatcher.send(*args)
          render_output(output)
        else
          $stderr.puts "Error: Command #{@command} not found."
        end
      end

      # taken from rip
      def parse_args(args)
        options, args = args.partition { |piece| piece =~ /^-/ }
        command = args.shift
        options = options.inject({}) do |hash, flag|
          key, value = flag.split('=')
          hash[key.sub(/^--?/,'').intern] = value.nil? ? true : value
          hash
        end
        [command, options, args]
      end

      def render_output(output)
        puts Hirb::View.render_output(output) || output.inspect
      end

      def print_usage
        puts "boson [COMMAND] [ARGS]"
      end
    end
  end
end