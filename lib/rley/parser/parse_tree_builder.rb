require_relative '../lexical/token_range'
require_relative '../syntax/terminal'
require_relative '../syntax/non_terminal'
require_relative '../gfg/end_vertex'
require_relative '../gfg/item_vertex'
require_relative '../gfg/start_vertex'
require_relative '../ptree/non_terminal_node'
require_relative '../ptree/terminal_node'
require_relative '../ptree/parse_tree'

module Rley # This module is used as a namespace
  module Parser # This module is used as a namespace
    # Structure used internally by ParseTreeBuilder class.
    CSTRawNode = Struct.new(:range, :symbol, :children) do
      def initialize(aRange, aSymbol)
        super
        self.range = aRange
        self.symbol = aSymbol
        self.children = nil
      end
    end # Struct


    # The purpose of a ParseTreeBuilder is to build piece by piece a CST
    # (Concrete Syntax Tree) from a sequence of input tokens and
    # visit events produced by walking over a GFGParsing object.
    # Uses the Builder GoF pattern.
    # The Builder pattern creates a complex object
    # (say, a parse tree) from simpler objects (terminal and non-terminal
    # nodes) and using a step by step approach.
    class ParseTreeBuilder
      # @return [Array<Token>] The sequence of input tokens
      attr_reader(:tokens)

      # Link to CST object (being) built.
      attr_reader(:result)


      # Create a new builder instance.
      # @param theTokens [Array<Token>] The sequence of input tokens.
      def initialize(theTokens)
        @tokens = theTokens
        @stack = []
      end

      # Receive events resulting from a visit of GFGParsing object.
      # These events are produced by a specialized Enumerator created
      # with a ParseWalkerFactory instance.
      # @param anEvent [Symbol] Kind of visit event. Should be: :visit
      # @param anEntry [ParseEntry] The entry being visited
      # @param anIndex [anIndex] The token index associated with anEntry
      def receive_event(anEvent, anEntry, anIndex)
        # puts "Event: #{anEvent} #{anEntry} #{anIndex}"
        if anEntry.dotted_entry? # A N => alpha . beta pattern?
          process_item_entry(anEvent, anEntry, anIndex)
        elsif anEntry.start_entry? # A .N pattern?
          process_start_entry(anEvent, anEntry, anIndex)
        elsif anEntry.end_entry? # A N. pattern?
          process_end_entry(anEvent, anEntry, anIndex)
        else
          raise NotImplementedError
        end

        @last_visitee = anEntry
      end

      protected

      # Return the stack
      def stack()
        return @stack
      end

      private

      # Return the top of stack element.
      def tos()
        return @stack.last
      end

      # Handler for visit events for ParseEntry matching N. pattern
      # @param anEvent [Symbol] Kind of visit event. Should be: :visit
      # @param anEntry [ParseEntry] The entry being visited
      # @param anIndex [anIndex] The token index at end of anEntry
      def process_end_entry(anEvent, anEntry, anIndex)
        case anEvent
          when :visit, :revisit
            range = { low: anEntry.origin, high: anIndex }
            non_terminal = entry2nonterm(anEntry)
            # Create raw node and push onto stack
            push_raw_node(range, non_terminal)
          #when :revisit
          #  # TODO: design specification
          else
            raise NotImplementedError, "Cannot handle event #{anEvent}"
        end
      end

      # Handler for visit events for ParseEntry matching .N pattern
      # @param anEvent [Symbol] Kind of visit event. Should be: :visit
      # @param _entry [ParseEntry] The entry being visited
      # @param _index [Integer] The token index at end of anEntry
      def process_start_entry(anEvent, _entry, _index)
        raise NotImplementedError unless %I[visit revisit].include?(anEvent)
      end

      # Handler for visit events for ParseEntry matching N => alpha* . beta*
      # @param anEvent [Symbol] Kind of visit event. Should be: :visit
      # @param anEntry [ParseEntry] The entry being visited
      # @param anIndex [anIndex] The token index at end of anEntry
      def process_item_entry(anEvent, anEntry, anIndex)
        # TODO: what if rhs is empty?
        case anEvent
          when :visit, :revisit
            dot_pos = anEntry.vertex.dotted_item.position
            if dot_pos.zero? || dot_pos < 0
              # Check for pattern: N => alpha* .
              process_exit_entry(anEntry, anIndex) if anEntry.exit_entry?

              # Check for pattern: N => . alpha*
              process_entry_entry(anEntry, anIndex) if anEntry.entry_entry?
            else
              # (pattern: N => alpha+ . beta+)
              process_middle_entry(anEntry, anIndex)
            end
          else
            $stderr.puts "waiko '#{anEvent}'"
            raise NotImplementedError
        end
      end

      # @param anEntry [ParseEntry] Entry matching (pattern: N => alpha* .)
      # @param anIndex [anIndex] The token index at end of anEntry
      def process_exit_entry(anEntry, anIndex)
        production = anEntry.vertex.dotted_item.production
        count_rhs = production.rhs.members.size
        init_TOS_children(count_rhs) # Create placeholders for children
        build_terminal(anEntry, anIndex) if terminal_before_dot?(anEntry)
      end

      # @param anEntry [ParseEntry] Entry matching pattern: N => alpha+ . beta+
      # @param anIndex [anIndex] The token index at end of anEntry
      def process_middle_entry(anEntry, anIndex)
        build_terminal(anEntry, anIndex) if terminal_before_dot?(anEntry)
      end

      # @param anEntry [ParseEntry] Entry matching (pattern: N => . alpha)
      # @param _index [Integer] The token index at end of anEntry
      def process_entry_entry(anEntry, _index)
        dotted_item = anEntry.vertex.dotted_item
        rule = dotted_item.production
        previous_tos = stack.pop
        non_terminal = entry2nonterm(anEntry)
        # For debugging purposes
        raise StandardError if previous_tos.symbol != non_terminal

        new_node = new_parent_node(rule, previous_tos.range,
                                   tokens, previous_tos.children)
        if stack.empty?
          @result = create_tree(new_node)
        else
          place_TOS_child(new_node, nil)
        end
      end

      # Create a raw node with given range
      # and push it on top of stack.
      def push_raw_node(aRange, aSymbol)
        raw_node = CSTRawNode.new(Lexical::TokenRange.new(aRange), aSymbol)
        stack.push(raw_node)
      end

      # Initialize children array of TOS with nil placeholders.
      # The number of elements equals the number of symbols at rhs.
      def init_TOS_children(aCount)
        tos.children = Array.new(aCount)
      end

      # Does the position on the left side of the dot correspond
      # a terminal symbol?
      # @param anEntry [ParseEntry] The entry being visited
      def terminal_before_dot?(anEntry)
        prev_symbol = anEntry.prev_symbol
        return prev_symbol && prev_symbol.terminal?
      end

      # A terminal symbol was detected at left of dot.
      # Build a raw node for that terminal and make it
      # a child of TOS.
      # @param anEntry [ParseEntry] The entry being visited
      # @param anIndex [anIndex] The token index at end of anEntry
      def build_terminal(anEntry, anIndex)
        # First, build node for terminal...
        term_symbol = anEntry.prev_symbol
        token_position = anIndex - 1
        token = tokens[token_position]
        prod = anEntry.vertex.dotted_item.production
        term_node = new_leaf_node(prod, term_symbol, token_position, token)

        # Second make it a child of TOS...
        pos = anEntry.vertex.dotted_item.prev_position # pos. in rhs of rule
        place_TOS_child(term_node, pos)
      end

      # Place the given node object as one of the children of the TOS
      # (TOS = Top Of Stack).
      # Each child has a position that is dictated by the position of the
      # related grammar symbol in the right-handed side (RHS) of the grammar
      # rule.
      # @param aNode [TerminalNode, NonTerminalNode] Node object to be placed
      # @param aRHSPos [Integer, NilClass] Position in RHS of rule.
      # If the position is provided, then the node will placed in the children
      # array at that position.
      # If the position is nil, then the node will be placed at the position of
      # the rightmost nil element in children array.
      def place_TOS_child(aNode, aRHSPos)
        if aRHSPos.nil?
          # Retrieve index of most rightmost nil child...
          pos = tos.children.rindex(&:nil?)
          raise StandardError, 'Internal error' if pos.nil?
        else
          pos = aRHSPos
        end

        tos.children[pos] = aNode
      end

      # Retrieve non-terminal symbol of given parse entry
      def entry2nonterm(anEntry)
        case anEntry.vertex
          when GFG::StartVertex, GFG::EndVertex
            non_terminal = anEntry.vertex.non_terminal
          when GFG::ItemVertex
            non_terminal = anEntry.vertex.lhs
        end

        return non_terminal
      end
    end # class
  end # module
end # module

# End of file
