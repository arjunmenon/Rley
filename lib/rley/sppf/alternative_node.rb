require_relative 'composite_node'

module Rley # This module is used as a namespace
  module SPPF # This module is used as a namespace
    # A node in a parse forest that is a child
    # of a parent node with :or refinement
    class AlternativeNode < CompositeNode
      # GFG vertex label
      attr_reader(:label)

      # Link to lhs symbol
      attr_reader(:symbol)

      # @param aVertex [ItemVertex] An GFG vertex that corresponds
      # a dotted item (with the dot at the end)for the alternative under
      # consideration.
      # @param aRange [TokenRange]
      def initialize(aVertex, aRange)
        super(aRange)
        @label = aVertex.label
        @symbol = aVertex.dotted_item.lhs
      end

      # Emit a (formatted) string representation of the node.
      # Mainly used for diagnosis/debugging purposes.
      def to_string(indentation)
        return "Alt(#{label})#{range.to_string(indentation)}"
      end
    end # class
  end # module
end # module
# End of file
