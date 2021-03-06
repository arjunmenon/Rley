require_relative 'parse_walker_factory'

module Rley # This module is used as a namespace
  module Parser # This module is used as a namespace
    # Utility class that helps to create a representation of a parse from
    # a given Parsing object.
    class ParseRepCreator
      # @return [GFGParsing] Link to Parsing object (= results of recognizer)
      attr_reader(:parsing)
      
      # Constructor. Creates and initialize a ParseRepCreator instance.
      # @return [ParseRepCreator]
      def initialize(aParsingResult)
        @parsing = aParsingResult
      end      
      
      # Factory method that produces the representation of the parse.
      # @return [ParseTree] The parse representation.
      def create(aBuilder = nil)
        a_walker = walker(parsing)
        a_builder = builder(parsing, aBuilder)

        begin
          loop do
            event = a_walker.next
            # puts "EVENT #{event[0]} #{event[1]}"
            a_builder.receive_event(*event)
          end
        rescue StopIteration
          # Do nothing
        end

        return a_builder.result
      end
      
      private
      
      # Create a Parsing walker, that is, an object
      # that will iterate over the relevant nodes (= parsing entries)
      # of a GFGParsing
      def walker(aParseResult)
        walker_factory = ParseWalkerFactory.new
        accept_entry = aParseResult.accepting_entry
        accept_index = aParseResult.chart.last_index
        walker_factory.build_walker(accept_entry, accept_index, jump_to_start)
      end

      # By default, when a end vertex is re-visited don't jump
      # its corresponding start vertex.
      def jump_to_start()
        false
      end
      
    end # class
  end # module
end # module

# End of file 
   