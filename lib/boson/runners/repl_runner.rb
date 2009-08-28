module Boson
  class ReplRunner < Runner
    class <<self
      def activate(options={})
        init(options) unless @initialized
        Library.load(options[:libraries], options) if options[:libraries]
      end

      def init(options={})
        super
        defaults = boson_libraries
        defaults << IRB::ExtendCommandBundle if Object.const_defined?(:IRB) && IRB.const_defined?(:ExtendCommandBundle)
        defaults += Boson.config[:defaults]
        Library.load(defaults, options)
        @initialized = true
      end
    end
  end
end
  