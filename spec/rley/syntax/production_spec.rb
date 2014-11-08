require_relative '../../spec_helper'

require_relative '../../../lib/rley/syntax/terminal'
require_relative '../../../lib/rley/syntax/non_terminal'
require_relative '../../../lib/rley/syntax/symbol_seq'

# Load the class under test
require_relative '../../../lib/rley/syntax/production'

module Rley # Open this namespace to avoid module qualifier prefixes
  module Syntax # Open this namespace to avoid module qualifier prefixes

  describe Production do
    let(:sentence) { NonTerminal.new('Sentence') }
    let(:np) { NonTerminal.new('NP') }
    let(:vp) { NonTerminal.new('VP') }
    let(:sequence) { [np, vp] }

    # Default instantiation rule
    subject { Production.new(sentence, sequence) }

    context 'Initialization:' do
      it 'should be created with a non-terminal and a symbol sequence' do
        expect { Production.new(sentence, sequence) }.not_to raise_error
      end

      it 'should know its lhs' do
        expect(subject.lhs).to eq(sentence)
        expect(subject.head).to eq(sentence)
      end

      it 'should know its rhs' do
        expect(subject.rhs).to eq(sequence)
        expect(subject.body).to eq(sequence)
      end
      
      it 'should know whether its rhs is empty' do
        expect(subject).not_to be_empty  

        instance = Production.new(sentence, [])
        expect(instance).to be_empty
      end
    end # context

  end # describe

  end # module
end # module

# End of file