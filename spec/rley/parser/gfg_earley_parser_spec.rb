require_relative '../../spec_helper'
require 'stringio'
require_relative '../../../lib/rley/syntax/verbatim_symbol'
require_relative '../../../lib/rley/syntax/non_terminal'
require_relative '../../../lib/rley/syntax/production'
require_relative '../../../lib/rley/syntax/grammar_builder'
require_relative '../../../lib/rley/parser/token'
require_relative '../../../lib/rley/parser/dotted_item'
require_relative '../../../lib/rley/parser/gfg_parsing'
require_relative '../support/grammar_abc_helper'
require_relative '../support/ambiguous_grammar_helper'
require_relative '../support/grammar_helper'
require_relative '../support/expectation_helper'

# Load the class under test
require_relative '../../../lib/rley/parser/gfg_earley_parser'

module Rley # Open this namespace to avoid module qualifier prefixes
  module Parser # Open this namespace to avoid module qualifier prefixes
    describe GFGEarleyParser do
      include GrammarABCHelper # Mix-in module with builder for grammar abc
      include GrammarHelper # Mix-in with method for creating token sequence
      include ExpectationHelper # Mix-in with expectation on parse entry sets

      # Factory method. Build a production with the given sequence
      # of symbols as its rhs.
      let(:grammar_abc) do
        builder = grammar_abc_builder
        builder.grammar
      end

      let(:grm1_tokens) do
        build_token_sequence(%w(a a b c c), grammar_abc)
      end


      # Grammar 2: A simple arithmetic expression language
      # (based on example in article on Earley's algorithm in Wikipedia)
      # P ::= S.
      # S ::= S "+" M.
      # S ::= M.
      # M ::= M "*" T.
      # M ::= T.
      # T ::= an integer number token.
      # Let's create the grammar piece by piece
      let(:nt_P) { Syntax::NonTerminal.new('P') }
      let(:nt_S) { Syntax::NonTerminal.new('S') }
      let(:nt_M) { Syntax::NonTerminal.new('M') }
      let(:nt_T) { Syntax::NonTerminal.new('T') }
      let(:plus) { Syntax::VerbatimSymbol.new('+') }
      let(:star) { Syntax::VerbatimSymbol.new('*') }
      let(:integer) do
        integer_pattern = /[-+]?[0-9]+/	# Decimal notation
        Syntax::Literal.new('integer', integer_pattern)
      end
      let(:prod_P) { Syntax::Production.new(nt_P, [nt_S]) }
      let(:prod_S1) { Syntax::Production.new(nt_S, [nt_S, plus, nt_M]) }
      let(:prod_S2) { Syntax::Production.new(nt_S, [nt_M]) }
      let(:prod_M1) { Syntax::Production.new(nt_M, [nt_M, star, nt_T]) }
      let(:prod_M2) { Syntax::Production.new(nt_M, [nt_T]) }
      let(:prod_T) { Syntax::Production.new(nt_T, [integer]) }
      let(:grammar_expr) do
        all_prods = [prod_P, prod_S1, prod_S2, prod_M1, prod_M2, prod_T]
        Syntax::Grammar.new(all_prods)
      end

      # Helper method that mimicks the output of a tokenizer
      # for the language specified by grammar_expr
      def grm2_tokens()       
        input_sequence = [ {'2' => 'integer'}, '+', {'3' => 'integer'},
          '*', {'4' => 'integer'}
        ]
        return  build_token_sequence(input_sequence, grammar_expr)
      end

      # Default instantiation rule
      subject { GFGEarleyParser.new(grammar_abc) }

      context 'Initialization:' do
        it 'should be created with a grammar' do
          expect { GFGEarleyParser.new(grammar_abc) }.not_to raise_error
        end

        it 'should know its grammar' do
          expect(subject.grammar).to eq(grammar_abc)
        end

        it 'should know its dotted items' do
          expect(subject.dotted_items.size).to eq(8)
        end

        it 'should know its flow graph' do
          expect(subject.gf_graph).to be_kind_of(GFG::GrmFlowGraph)
        end
      end # context

      context 'Parsing: ' do
        it 'should parse a valid simple input' do
          parse_result = subject.parse(grm1_tokens)
          expect(parse_result.success?).to eq(true)
          # expect(parse_result.ambiguous?).to eq(false)
          ######################
          # Expectation chart[0]:
          expected = [
            '.S | 0',               # initialization
            'S => . A | 0',         # start rule
            '.A | 0',               # call rule
            'A => . a A c | 0',     # start rule
            'A => . b | 0'          # start rule
          ]
          compare_entry_texts(parse_result.chart[0], expected)
          expected_terminals(parse_result.chart[0], %w(a b))

          ######################
          # Expectation chart[1]:
          expected = [
            'A => a . A c | 0',     # scan 'a'
            '.A | 1',               # call rule
            'A => . a A c | 1',     # start rule
            'A => . b | 1'          # start rule
          ]
          entry_set_1 = parse_result.chart[1]
          expect(entry_set_1.entries.size).to eq(4)
          compare_entry_texts(entry_set_1, expected)
          expected_terminals(parse_result.chart[1], %w(a b))

          ######################
          # Expectation chart[2]:
          expected = [
            'A => a . A c | 1',     # scan 'a'
            '.A | 2',               # call rule
            'A => . a A c | 2',     # start rule
            'A => . b | 2'          # start rule
          ]
          entry_set_2 = parse_result.chart[2]
          expect(entry_set_2.entries.size).to eq(4)
          compare_entry_texts(entry_set_2, expected)
          expected_terminals(parse_result.chart[2], %w(a b))

          ######################
          # Expectation chart[3]:
          expected = [
            'A => b . | 2',      # scan 'b'
            'A. | 2',            # exit rule
            'A => a A . c | 1',  # end rule
          ]
          entry_set_3 = parse_result.chart[3]
          expect(entry_set_3.entries.size).to eq(3)
          compare_entry_texts(entry_set_3, expected)
          expected_terminals(parse_result.chart[3], %w(c))


          ######################
          # Expectation chart[4]:
          expected = [
            'A => a A c . | 1',   # scan 'c'
            'A. | 1',             # exit rule
            'A => a A . c | 0'    # end rule
          ]
          entry_set_4 = parse_result.chart[4]
          expect(entry_set_4.entries.size).to eq(3)
          compare_entry_texts(entry_set_4, expected)
          expected_terminals(parse_result.chart[4], %w(c))

          ######################
          # Expectation chart[5]:
          expected = [
            'A => a A c . | 0',  # scan 'c'
            'A. | 0',            # exit rule
            'S => A . | 0',      # end rule
            'S. | 0'             # exit rule
          ]
          entry_set_5 = parse_result.chart[5]
          expect(entry_set_5.entries.size).to eq(4)
          compare_entry_texts(entry_set_5, expected)
        end
=begin
        it 'should trace a parse with level 1' do
          # Substitute temporarily $stdout by a StringIO
          prev_ostream = $stdout
          $stdout = StringIO.new('', 'w')

          trace_level = 1
          subject.parse(grm1_tokens, trace_level)
          expectations = <<-SNIPPET
['a', 'a', 'b', 'c', 'c']
|. a . a . b . c . c .|
|>   .   .   .   .   .| [0:0] S => . A
|>   .   .   .   .   .| [0:0] A => . 'a' A 'c'
|>   .   .   .   .   .| [0:0] A => . 'b'
|[---]   .   .   .   .| [0:1] A => 'a' . A 'c'
|.   >   .   .   .   .| [1:1] A => . 'a' A 'c'
|.   >   .   .   .   .| [1:1] A => . 'b'
|.   [---]   .   .   .| [1:2] A => 'a' . A 'c'
|.   .   >   .   .   .| [2:2] A => . 'a' A 'c'
|.   .   >   .   .   .| [2:2] A => . 'b'
|.   .   [---]   .   .| [2:3] A => 'b' .
|.   [------->   .   .| [1:3] A => 'a' A . 'c'
|.   .   .   [---]   .| [3:4] A => 'a' A 'c' .
|[--------------->   .| [0:4] A => 'a' A . 'c'
|.   .   .   .   [---]| [4:5] A => 'a' A 'c' .
|[===================]| [0:5] S => A .
SNIPPET
          expect($stdout.string).to eq(expectations)

          # Restore standard ouput stream
          $stdout = prev_ostream
        end
=end

        it 'should parse a valid simple expression' do
          instance = GFGEarleyParser.new(grammar_expr)
          parse_result = instance.parse(grm2_tokens)
          expect(parse_result.success?).to eq(true)
          # expect(parse_result.ambiguous?).to eq(false)

          ###################### S(0): . 2 + 3 * 4
          # Expectation chart[0]:
          expected = [
            '.P | 0',               # Initialization
            'P => . S | 0',         # start rule
            '.S | 0',               # call rule
            "S => . S '+' M | 0",   # start rule
            'S => . M | 0',         # start rule
            '.M | 0',               # call rule
            "M => . M '*' T | 0",   # start rule
            'M => . T | 0',         # start rule
            '.T | 0',               # call rule
            'T => . integer | 0'    # start rule
          ]
          compare_entry_texts(parse_result.chart[0], expected)


          ###################### S(1): 2 . + 3 * 4
          # Expectation chart[1]:
          expected = [
            'T => integer . | 0',   # scan '2'
            'T. | 0',               # exit rule
            'M => T . | 0',         # end rule
            'M. | 0',               # exit rule
            'S => M . | 0',         # end rule
            "M => M . '*' T | 0",   # end rule
            'S. | 0',               # exit rule
            'P => S . | 0',         # end rule
            "S => S . '+' M | 0",   # end rule
            'P. | 0'                # exit rule
          ]
          compare_entry_texts(parse_result.chart[1], expected)


          ###################### S(2): 2 + . 3 * 4
          # Expectation chart[2]:
          expected = [
            "S => S '+' . M | 0",   # scan '+'
            '.M | 2',               # call rule
            "M => . M '*' T | 2",   # start rule
            'M => . T | 2',         # start rule
            '.T | 2',               # call rule
            'T => . integer | 2'    # start rule
          ]
          compare_entry_texts(parse_result.chart[2], expected)


          ###################### S(3): 2 + 3 . * 4
          # Expectation chart[3]:
          expected = [
            'T => integer . | 2',   # scan '3'
            'T. | 2',               # exit rule
            'M => T . | 2',         # end rule
            'M. | 2',               # exit rule
            "S => S '+' M . | 0",   # end rule
            "M => M . '*' T | 2",   # end rule
            'S. | 0',               # exit rule
            'P => S . | 0',         # end rule
            "S => S . '+' M | 0", # end rule
            'P. | 0'                # exit rule
          ]
          compare_entry_texts(parse_result.chart[3], expected)

          ###################### S(4): 2 + 3 * . 4
          # Expectation chart[4]:
          expected = [
            "M => M '*' . T | 2",   # scan '*'
            '.T | 4',               # call rule
            'T => . integer | 4'    # entry rule
          ]
          compare_entry_texts(parse_result.chart[4], expected)

          ###################### S(5): 2 + 3 * 4 .
          # Expectation chart[5]:
          expected = [
            'T => integer . | 4',   # scan '4'
            'T. | 4',               # exit rule
            "M => M '*' T . | 2",   # end rule
            'M. | 2',               # exit rule
            "S => S '+' M . | 0",   # end rule
            "M => M . '*' T | 2",   # end rule
            'S. | 0',               # exit rule
            'P => S . | 0',         # end rule
            "S => S . '+' M | 0",   # end rule
            'P. | 0'                # end rule
          ]
          compare_entry_texts(parse_result.chart[5], expected)
        end

        it 'should parse a nullable grammar' do
          # Simple but problematic grammar for the original Earley parser
          # (based on example in D. Grune, C. Jacobs "Parsing Techniques" book)
          # Ss =>  A A 'x';
          # A => ;
          t_x = Syntax::VerbatimSymbol.new('x')

          builder = Syntax::GrammarBuilder.new
          builder.add_terminals(t_x)
          builder.add_production('Ss' => %w(A A x))
          builder.add_production('A' => [])
          tokens = [ Token.new('x', t_x) ]

          instance = GFGEarleyParser.new(builder.grammar)
          expect { instance.parse(tokens) }.not_to raise_error
          parse_result = instance.parse(tokens)
          expect(parse_result.success?).to eq(true)
          ###################### S(0): . x
          # Expectation chart[0]:
          expected = [
            '.Ss | 0',              # Initialization
            "Ss => . A A 'x' | 0",  # start rule
            '.A | 0',               # call rule
            'A => . | 0',           # start rule
            'A. | 0',               # exit rule
            "Ss => A . A 'x' | 0",  # end rule
            "Ss => A A . 'x' | 0"   # end rule
          ]
          compare_entry_texts(parse_result.chart[0], expected)

          ###################### S(1): x .
          # Expectation chart[1]:
          expected = [
            "Ss => A A 'x' . | 0",  # scan 'x'
            'Ss. | 0'               # exit rule
          ]
          compare_entry_texts(parse_result.chart[1], expected)
        end

        it 'should parse an ambiguous grammar (I)' do
          # Grammar 3: A ambiguous arithmetic expression language
          # (based on example in article on Earley's algorithm in Wikipedia)
          # P => S.
          # S => S "+" S.
          # S => S "*" S.
          # S => L.
          # L => an integer number token.
          t_int = Syntax::Literal.new('integer', /[-+]?\d+/)
          t_plus = Syntax::VerbatimSymbol.new('+')
          t_star = Syntax::VerbatimSymbol.new('*')

          builder = Syntax::GrammarBuilder.new
          builder.add_terminals(t_int, t_plus, t_star)
          builder.add_production('P' => 'S')
          builder.add_production('S' => %w(S + S))
          builder.add_production('S' => %w(S * S))
          builder.add_production('S' => 'L')
          builder.add_production('L' => 'integer')
          input_sequence = [ 
            {'2' => 'integer'},
            '+', 
            {'3' => 'integer'}, 
            '*', 
            {'4' => 'integer'}
          ]
          tokens = build_token_sequence(input_sequence, builder.grammar)
          instance = GFGEarleyParser.new(builder.grammar)
          expect { instance.parse(tokens) }.not_to raise_error
          parse_result = instance.parse(tokens)
          expect(parse_result.success?).to eq(true)
          # expect(parse_result.ambiguous?).to eq(true)

          ###################### S(0): . 2 + 3 * 4
          # Expectation chart[0]:
          expected = [
            '.P | 0',             # Initialization
            'P => . S | 0',       # start rule
            '.S | 0',             # call rule
            "S => . S '+' S | 0", # entry rule
            "S => . S '*' S | 0", # entry rule
            'S => . L | 0',       # entry rule
            '.L | 0',             # call rule
            'L => . integer | 0'  # entry rule
          ]
          compare_entry_texts(parse_result.chart[0], expected)

          ###################### S(1): 2 . + 3 * 4
          # Expectation chart[1]:
          expected = [
            'L => integer . | 0', # scan '2'
            'L. | 0',             # exit rule
            'S => L . | 0',       # end rule
            'S. | 0',             # exit rule
            'P => S . | 0',       # end rule
            "S => S . '+' S | 0", # end rule
            "S => S . '*' S | 0", # end rule
            'P. | 0'              # exit rule
          ]
          compare_entry_texts(parse_result.chart[1], expected)

          ###################### S(2): 2 + . 3 * 4
          # Expectation chart[2]:
          expected = [
            "S => S '+' . S | 0", # scan '+'
            '.S | 2',             # call rule
            "S => . S '+' S | 2", # entry rule
            "S => . S '*' S | 2", # entry rule
            'S => . L | 2',       # entry rule
            '.L | 2',             # call rule
            'L => . integer | 2'  # entry rule
          ]
          compare_entry_texts(parse_result.chart[2], expected)

          ###################### S(3): 2 + 3 . * 4
          # Expectation chart[3]:
          expected = [
            'L => integer . | 2', # scan '3'
            'L. | 2',             # exit rule
            'S => L . | 2',       # end rule
            'S. | 2',             # exit rule
            "S => S '+' S . | 0", # end rule
            "S => S . '+' S | 2", # end rule
            "S => S . '*' S | 2", # end rule
            'S. | 0',             # exit rule
            'P => S . | 0',       # end rule
            "S => S . '+' S | 0", # end rule
            "S => S . '*' S | 0", # end rule
            'P. | 0',             # exit rule
          ]
          compare_entry_texts(parse_result.chart[3], expected)

          ###################### S(4): 2 + 3 * . 4
          # Expectation chart[4]:
          expected = [
            "S => S '*' . S | 2", # scan '*'
            "S => S '*' . S | 0", # scan '*'
            '.S | 4',             # call rule
            "S => . S '+' S | 4", # entry rule
            "S => . S '*' S | 4", # entry rule
            'S => . L | 4',       # entry rule
            '.L | 4',             # call rule
            'L => . integer | 4'  # entry rule
          ]
          compare_entry_texts(parse_result.chart[4], expected)

          ###################### S(5): 2 + 3 * 4 .
          # Expectation chart[5]:
          expected = [
            'L => integer . | 4',   # scan '4'
            'L. | 4',               # exit rule
            'S => L . | 4',         # end rule
            'S. | 4',               # exit rule
            "S => S '*' S . | 2",   # end rule
            "S => S '*' S . | 0",   # end rule
            "S => S . '+' S | 4",   # end rule
            "S => S . '*' S | 4",   # end rule
            'S. | 2',               # exit rule
            'S. | 0',               # exit rule
            "S => S '+' S . | 0",   # end rule
            "S => S . '+' S | 2",   # end rule
            "S => S . '*' S | 2",   # end rule
            'P => S . | 0',         # end rule
            "S => S . '+' S | 0",   # end rule
            "S => S . '*' S | 0",   # end rule
            'P. | 0'                # exit rule
          ]
          compare_entry_texts(parse_result.chart[5], expected)
          
          expected_antecedents = {
            'L => integer . | 4' => ['L => . integer | 4'],
            'L. | 4' => ['L => integer . | 4'],
            'S => L . | 4' => ['L. | 4'],
            'S. | 4' => ['S => L . | 4'],
            "S => S '*' S . | 2" => ['S. | 4'],
            "S => S '*' S . | 0" => ['S. | 4'],
            "S => S . '+' S | 4" => ['S. | 4'], 
            "S => S . '*' S | 4" => ['S. | 4'],
            'S. | 2' => ["S => S '*' S . | 2"],
            'S. | 0' => ["S => S '*' S . | 0", "S => S '+' S . | 0"],
            "S => S '+' S . | 0" => ['S. | 2'],
            "S => S . '+' S | 2" => ['S. | 2'],
            "S => S . '*' S | 2" => ['S. | 2'],
            'P => S . | 0'  => ['S. | 0'],
            "S => S . '+' S | 0" => ['S. | 0'],
            "S => S . '*' S | 0" => ['S. | 0'],
            'P. | 0' => ['P => S . | 0']
          }
          check_antecedence(parse_result, 5, expected_antecedents)
        end

        it 'should parse an ambiguous grammar (II)' do
          extend(AmbiguousGrammarHelper)
          grammar = grammar_builder.grammar
          instance = GFGEarleyParser.new(grammar)
          tokens = tokenize('abc + def + ghi', grammar)
          expect { instance.parse(tokens) }.not_to raise_error
          parse_result = instance.parse(tokens)
          expect(parse_result.success?).to eq(true)
          # expect(parse_result.ambiguous?).to eq(true)

          ###################### S(0): . abc + def + ghi
          # Expectation chart[0]:
          expected = [
            '.S | 0',             # Initialization
            'S => . E | 0',       # start rule
            '.E | 0',             # call rule
            'E => . E + E | 0',   # start rule
            'E => . id | 0'       # start rule
          ]
          compare_entry_texts(parse_result.chart[0], expected)

          ###################### S(1): abc . + def + ghi
          # Expectation chart[1]:
          expected = [
            'E => id . | 0',      # scan 'abc'
            'E. | 0',              # exit rule
            'S => E . | 0',       # end rule
            'E => E . + E | 0',   # end rule
            'S. | 0'              # exit rule
          ]
          compare_entry_texts(parse_result.chart[1], expected)

          ###################### S(2): abc + . def + ghi
          # Expectation chart[2]:
          expected = [
            'E => E + . E | 0',   # Scan '+'
            '.E | 2',             # call rule
            'E => . E + E | 2',   # entry rule
            'E => . id | 2'       # entry rule
          ]
          compare_entry_texts(parse_result.chart[2], expected)

          ###################### S(3): abc + def .  + ghi
          # Expectation chart[3]:
          expected = [
            'E => id . | 2',      # Scan 'def'
            'E. | 2',             # exit rule
            'E => E + E . | 0',   # end rule
            'E => E . + E | 2',   # end rule
            'E. | 0',             # exit rule
            'S => E . | 0',       # end rule
            'E => E . + E | 0',   # end rule
            'S. | 0'              # exit rule
          ]
          compare_entry_texts(parse_result.chart[3], expected)

          ###################### S(4): abc + def + . ghi
          # Expectation chart[4]:
          expected = [
            'E => E + . E | 2',   # Scan '+'
            'E => E + . E | 0',   # Scan '+'
            '.E | 4',             # call rule
            'E => . E + E | 4',   # start rule
            'E => . id | 4'       # start rule
          ]
          compare_entry_texts(parse_result.chart[4], expected)

          ###################### S(5): abc + def + ghi .
          # Expectation chart[5]:
          expected = [
            'E => id . | 4',      # Scan 'ghi'
            'E. | 4',             # exit rule
            'E => E + E . | 2',   # end rule
            'E => E + E . | 0',   # end rule
            'E => E . + E | 4',   # end rule
            'E. | 2',             # exit rule
            'E. | 0',             # exit rule
            'E => E . + E | 2',   # end rule
            'S => E . | 0',       # end rule
            'E => E . + E | 0',   # end rule
            'S. | 0',             # exit rule
          ]
          compare_entry_texts(parse_result.chart[5], expected)
        end

        it 'should parse an invalid simple input' do
          # Parse an erroneous input (b is missing)
          wrong = build_token_sequence(%w(a a c c), grammar_abc)

          err_msg = <<-MSG
Syntax error at or near token 3>>>c<<<:
Expected one of: ['a', 'b'], found a 'c' instead.
MSG
          err = StandardError
          expect { subject.parse(wrong) }
            .to raise_error(err, err_msg.chomp)
        end

        it 'should parse a common sample' do
          # Grammar based on example found in paper of K. Pingali, G. Bilardi:
          # "A Graphical Model for Context-Free Gammar Parsing"
          t_int = Syntax::Literal.new('int', /[-+]?\d+/)
          t_plus = Syntax::VerbatimSymbol.new('+')
          t_lparen = Syntax::VerbatimSymbol.new('(')
          t_rparen = Syntax::VerbatimSymbol.new(')')

          builder = Syntax::GrammarBuilder.new
          builder.add_terminals(t_int, t_plus, t_lparen, t_rparen)
          builder.add_production('S' => 'E')
          builder.add_production('E' => 'int')
          builder.add_production('E' => %w[( E + E )])
          builder.add_production('E' => %w( E + E ))
          input_sequence = [ 
            {'7' => 'int'},
            '+', 
            {'8' => 'int'}, 
            '+', 
            {'9' => 'int'}
          ]
          tokens = build_token_sequence(input_sequence, builder.grammar)
          instance = GFGEarleyParser.new(builder.grammar)
          parse_result = instance.parse(tokens)
          expect(parse_result.success?).to eq(true)
          ###################### S(0) == . 7 + 8 + 9
          # Expectation chart[0]:
          expected = [
            '.S | 0',                     # initialization
            'S => . E | 0',               # start rule
            '.E | 0',                     # call rule
            'E => . int | 0',             # start rule
            "E => . '(' E '+' E ')' | 0", # start rule
            "E => . E '+' E | 0"          # start rule
          ]
          compare_entry_texts(parse_result.chart[0], expected)

          ###################### S(1) == 7 . + 8 + 9
          # Expectation chart[1]:
          expected = [
            'E => int . | 0',             # scan '7'
            'E. | 0',                     # exit rule
            'S => E . | 0',               # end rule
            "E => E . '+' E | 0",         # end rule
            'S. | 0'                      # exit rule
          ]
          compare_entry_texts(parse_result.chart[1], expected)

          ###################### S(2) == 7 + . 8 + 9
          # Expectation chart[2]:
          expected = [
            "E => E '+' . E | 0",         # scan '+'
            '.E | 2',                     # exit rule
           'E => . int | 2',              # start rule
            "E => . '(' E '+' E ')' | 2", # start rule
            "E => . E '+' E | 2"          # start rule
          ]
          compare_entry_texts(parse_result.chart[2], expected)

          ###################### S(3) == 7 + 8 . + 9
          # Expectation chart[3]:
          expected = [
            'E => int . | 2',             # scan '8'
            'E. | 2',                     # exit rule
            "E => E '+' E . | 0",         # end rule
            "E => E . '+' E | 2",         # end rule
            'E. | 0',                     # exit rule
            'S => E . | 0',               # end rule
            "E => E . '+' E | 0",         # end rule
            'S. | 0'                      # exit rule
          ]
          compare_entry_texts(parse_result.chart[3], expected)

          ###################### S(4) == 7 + 8 + . 9
          # Expectation chart[4]:
          expected = [
            "E => E '+' . E | 2",         # scan '+'
            "E => E '+' . E | 0",         # scan '+'
            '.E | 4',                     # exit rule
            'E => . int | 4',             # start rule
            "E => . '(' E '+' E ')' | 4", # start rule
            "E => . E '+' E | 4"          # start rule
          ]
          compare_entry_texts(parse_result.chart[4], expected)

          ###################### S(5) == 7 + 8 + 9 .
          # Expectation chart[5]:
          expected = [
            'E => int . | 4',             # scan '9'
            'E. | 4',                     # exit rule
            "E => E '+' E . | 2",         # end rule
            "E => E '+' E . | 0",         # end rule
            "E => E . '+' E | 4",         # exit rule (not shown in paper)
            'E. | 2',                     # exit rule
            'E. | 0',                     # exit rule
            "E => E . '+' E | 2",         # end rule
            'S => E . | 0',               # end rule
            "E => E . '+' E | 0",         # end rule
            'S. | 0'
          ]
          compare_entry_texts(parse_result.chart[5], expected)
        end

        it 'should parse a grammar with nullable nonterminals' do
          # Grammar 4: A grammar with nullable nonterminal
          # based on example from "Parsing Techniques" book
          # (D. Grune, C. Jabobs)
          # Z ::= E.
          # E ::= E Q F.
          # E ::= F.
          # F ::= a.
          # Q ::= *.
          # Q ::= /.
          # Q ::=.
          t_a = Syntax::VerbatimSymbol.new('a')
          t_star = Syntax::VerbatimSymbol.new('*')
          t_slash = Syntax::VerbatimSymbol.new('/')

          builder = Syntax::GrammarBuilder.new
          builder.add_terminals(t_a, t_star, t_slash)
          builder.add_production('Z' => 'E')
          builder.add_production('E' => %w(E Q F))
          builder.add_production('E' => 'F')
          builder.add_production('F' => t_a)
          builder.add_production('Q' => t_star)
          builder.add_production('Q' => t_slash)
          builder.add_production('Q' => []) # Empty production
          
          tokens = build_token_sequence(%w(a a / a), builder.grammar)
          instance = GFGEarleyParser.new(builder.grammar)
          expect { instance.parse(tokens) }.not_to raise_error
          parse_result = instance.parse(tokens)
          expect(parse_result.success?).to eq(true)

          ###################### S(0) == . a a / a
          # Expectation chart[0]:
          expected = [
            '.Z | 0',           # initialization
            'Z => . E | 0',     # start rule
            '.E | 0',           # call rule
            'E => . E Q F | 0', # start rule
            'E => . F | 0',     # start rule
            '.F | 0',           # call rule
            "F => . 'a' | 0"    # start rule
          ]
          compare_entry_texts(parse_result.chart[0], expected)

          ###################### S(1) == a . a / a
          # Expectation chart[1]:
          expected = [
            "F => 'a' . | 0",   # scan 'a'
            'F. | 0',           # exit rule
            'E => F . | 0',     # end rule
            'E. | 0',           # exit rule
            'Z => E . | 0',     # end rule
            'E => E . Q F | 0', # end rule
            'Z. | 0',           # exit rule
            '.Q | 1',           # call rule
            "Q => . '*' | 1",   # start rule
            "Q => . '/' | 1",   # start rule
            'Q => . | 1',       # start rule
            'Q. | 1',           # exit rule
            'E => E Q . F | 0', # end rule
            '.F | 1',           # call rule
            "F => . 'a' | 1"    # start rule
          ]
          compare_entry_texts(parse_result.chart[1], expected)

          ###################### S(2) == a a . / a
          # Expectation chart[2]:
          expected = [
            "F => 'a' . | 1",   # scan 'a'
            'F. | 1',           # exit rule
            'E => E Q F . | 0', # end rule
            'E. | 0',           # exit rule
            'Z => E . | 0',     # end rule
            'E => E . Q F | 0', # end rule
            'Z. | 0',           # exit rule
            '.Q | 2',           # call rule
            "Q => . '*' | 2",   # start rule
            "Q => . '/' | 2",   # start rule
            'Q => . | 2',       # start rule
            'Q. | 2',           # exit rule
            'E => E Q . F | 0', # end rule
            '.F | 2',           # call rule
            "F => . 'a' | 2"    # start rule
          ]
          compare_entry_texts(parse_result.chart[2], expected)


          ###################### S(3) == a a / . a
          # Expectation chart[3]:
          expected = [
            "Q => '/' . | 2",   # scan '/'
            'Q. | 2',           # exit rule
            'E => E Q . F | 0', # end rule
            '.F | 3',           # call rule
            "F => . 'a' | 3"    # entry rule
          ]
          compare_entry_texts(parse_result.chart[3], expected)


          ###################### S(4) == a a / a .
          # Expectation chart[4]:
          expected = [
            "F => 'a' . | 3",   # scan 'a'
            'F. | 3',           # exit rule
            'E => E Q F . | 0', # end rule
            'E. | 0',           # exit rule
            'Z => E . | 0',     # end rule
            'E => E . Q F | 0', # end rule
            'Z. | 0',           # exit rule
            '.Q | 4',           # call rule
            "Q => . '*' | 4",   # start rule
            "Q => . '/' | 4",   # start rule
            'Q => . | 4',       # start rule
            'Q. | 4',           # exit rule
            'E => E Q . F | 0', # end rule
            '.F | 4',           # call rule
            "F => . 'a' | 4"    # entry rule
          ]
          compare_entry_texts(parse_result.chart[4], expected)
        end

        it 'should parse a right recursive grammar' do
          # Simple right recursive grammar
          # based on example in D. Grune, C. Jacobs "Parsing Techniques" book
          # pp. 224 et sq.
          # S =>  a S;
          # S => ;
          # This grammar requires a time that is quadratic in the number of
          # input tokens

          t_x = Syntax::VerbatimSymbol.new('x')

          builder = Syntax::GrammarBuilder.new
          builder.add_terminals('a')
          builder.add_production('S' => %w(a S))
          builder.add_production('S' => [])
          grammar = builder.grammar
          tokens = build_token_sequence(%w(a a a a), grammar)

          instance = GFGEarleyParser.new(grammar)
          parse_result = instance.parse(tokens)
          expect(parse_result.success?).to eq(true)
          ###################### S(0): . a a a a
          # Expectation chart[0]:
          expected = [
            '.S | 0',               # Initialization
            'S => . a S | 0',       # start rule
            'S => . | 0',           # start rule
            'S. | 0'                # exit rule
          ]
          compare_entry_texts(parse_result.chart[0], expected)

          ###################### S(1): a . a a a
          # Expectation chart[1]:
          expected = [
            'S => a . S | 0',       # scan 'a'
            '.S | 1',               # call rule
            'S => . a S | 1',       # start rule
            'S => . | 1',           # start rule
            'S. | 1',               # exit rule
            'S => a S . | 0'        # end rule
          ]
          compare_entry_texts(parse_result.chart[1], expected)

          ###################### S(2): a a . a a
          # Expectation chart[2]:
          expected = [
            'S => a . S | 1',       # scan 'a'
            '.S | 2',               # call rule
            'S => . a S | 2',       # start rule
            'S => . | 2',           # start rule
            'S. | 2',               # exit rule
            'S => a S . | 1',       # end rule
            'S. | 1',               # exit rule
            'S => a S . | 0',       # end rule
            'S. | 0'                # exit rule
          ]
          compare_entry_texts(parse_result.chart[2], expected)

          ###################### S(3): a a a . a
          # Expectation chart[3]:
          expected = [
            'S => a . S | 2',       # scan 'a'
            '.S | 3',               # call rule
            'S => . a S | 3',       # start rule
            'S => . | 3',           # start rule
            'S. | 3',               # exit rule
            'S => a S . | 2',       # end rule
            'S. | 2',               # exit rule
            'S => a S . | 1',       # end rule
            'S. | 1',               # exit rule
            'S => a S . | 0',       # end rule
            'S. | 0'                # exit rule
          ]
          compare_entry_texts(parse_result.chart[3], expected)

          ###################### S(4): a a a a .
          # Expectation chart[4]:
          expected = [
            'S => a . S | 3',       # scan 'a'
            '.S | 4',               # call rule
            'S => . a S | 4',       # start rule
            'S => . | 4',           # start rule
            'S. | 4',               # exit rule
            'S => a S . | 3',       # end rule
            'S. | 3',               # exit rule
            'S => a S . | 2',       # end rule
            'S. | 2',               # exit rule
            'S => a S . | 1',       # end rule
            'S. | 1',               # exit rule
            'S => a S . | 0',       # end rule
            'S. | 0'                # exit rule
          ]
          compare_entry_texts(parse_result.chart[4], expected)
        end

      end # context
    end # describe
  end # module
end # module

# End of module
