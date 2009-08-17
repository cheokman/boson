module Boson
  module Libraries
    module Core
      def commands(*args)
        puts ::Hirb::Helpers::Table.render(Boson.commands.search(*args), :fields=>[:name, :lib, :alias, :description])
      end

      def libraries(query=nil)
        puts ::Hirb::Helpers::Table.render(Boson.libraries.search(query, :loaded=>true), :fields=>[:name, :loaded, :commands, :gems],
          :filters=>{:gems=>lambda {|e| e.join(',')}, :commands=>:size} )
      end
    
      def load_library(library, options={})
        Boson::Loader.load_library(library, {:verbose=>true}.merge!(options))
      end

      def reload_library(name)
        Boson::Loader.reload_library(library)
      end
    end
  end
end
