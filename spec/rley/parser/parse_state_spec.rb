require_relative '../../spec_helper'

require_relative '../../../lib/rley/syntax/terminal'
require_relative '../../../lib/rley/syntax/non_terminal'
require_relative '../../../lib/rley/syntax/production'
require_relative '../../../lib/rley/parser/dotted_item'

# Load the class under test
require_relative '../../../lib/rley/parser/parse_state'

module Rley # Open this namespace to avoid module qualifier prefixes
  module Parser # Open this namespace to avoid module qualifier prefixes

  describe ParseState do

    let(:t_a) { Syntax::Terminal.new('A') }
    let(:t_b) { Syntax::Terminal.new('B') }
    let(:t_c) { Syntax::Terminal.new('C') }
    let(:nt_sentence) { Syntax::NonTerminal.new('sentence') }

    let(:sample_prod) do
      Syntax::Production.new(nt_sentence, [t_a, t_b, t_c])
    end

    let(:other_prod) do
      Syntax::Production.new(nt_sentence, [t_a])
    end
    
    let(:empty_prod) do
      Syntax::Production.new(nt_sentence,[])
    end
  
    let(:origin_value) { 3 }
    let(:dotted_rule) { DottedItem.new(sample_prod, 2) }
    let(:other_dotted_rule) { double('mock-dotted-item') }

    # Default instantiation rule
    subject { ParseState.new(dotted_rule, origin_value) }

    context 'Initialization:' do

      it 'should be created with a lexeme and a terminal argument' do
        expect { ParseState.new(dotted_rule, origin_value) }.not_to raise_error
      end

      it 'should know the related dotted rule' do
        expect(subject.dotted_rule).to eq(dotted_rule)
      end

      it 'should know the origin value' do
        expect(subject.origin).to eq(origin_value)
      end


    end # context

    context 'Provided services:' do
      it 'should compare with itself' do
        expect(subject == subject).to eq(true)
      end

      it 'should compare with another' do
        equal = ParseState.new(dotted_rule, origin_value)
        expect(subject == equal).to eq(true)

        # Same dotted_rule, different origin
        diff_origin = ParseState.new(dotted_rule, 2)
        expect(subject == diff_origin).to eq(false)

        # Different dotted item, same origin
        diff_rule = ParseState.new(other_dotted_rule, 3)
        expect(subject == diff_rule).to eq(false)
      end
      
      it 'should know if the parsing reached the end of the production' do
        expect(subject).not_to be_complete
        at_end = DottedItem.new(sample_prod, 3)

        instance = ParseState.new(at_end, 2)
        expect(instance).to be_complete        
      end
      
      it 'should know the next expected symbol' do
        expect(subject.next_symbol).to eq(t_c)     
      end
    end # context

  end # describe

  end # module
end # module

# End of file