# Load the builder class
require_relative '../../../lib/rley/syntax/grammar_builder'
require_relative '../../../lib/rley/lexical/token'


module GrammarL0Helper
  ########################################
  # Factory method. Define a grammar for a micro English-like language
  # based on Jurafky & Martin L0 language (chapter 12 of the book).
  # It defines the syntax of a sentence in a language with a
  # very limited syntax and lexicon in the context of airline reservation.
  def grammar_l0_builder()
    builder = Rley::Syntax::GrammarBuilder.new do
      add_terminals('Noun', 'Verb', 'Pronoun', 'Proper-Noun')
      add_terminals('Determiner', 'Preposition')
      rule 'S' => %w[NP VP]
      rule 'NP' => 'Pronoun'
      rule 'NP' => 'Proper-Noun'
      rule 'NP' => %w[Determiner Nominal]
      rule 'Nominal' => %w[Nominal Noun]
      rule 'Nominal' => 'Noun'
      rule 'VP' => 'Verb'
      rule 'VP' => %w[Verb NP]
      rule 'VP' => %w[Verb NP PP]
      rule 'VP' => %w[Verb PP]
      rule 'PP' => %w[Preposition PP]
    end
    builder
  end

  # Return the language lexicon.
  # A lexicon is just a Hash with pairs of the form:
  # word => terminal symbol name
  def lexicon_l0()
    return {
      'flight' => 'Noun',
      'breeze' => 'Noun',
      'trip' => 'Noun',
      'morning' => 'Noun',
      'is' => 'Verb',
      'prefer' => 'Verb',
      'like' => 'Verb',
      'need' => 'Verb',
      'want' => 'Verb',
      'fly' => 'Verb',
      'me' => 'Pronoun',
      'I' => 'Pronoun',
      'you' => 'Pronoun',
      'it' => 'Pronoun',
      'Alaska' => 'Proper-Noun',
      'Baltimore' => 'Proper-Noun',
      'Chicago' => 'Proper-Noun',
      'United' => 'Proper-Noun',
      'American' => 'Proper-Noun',
      'the' => 'Determiner',
      'a' => 'Determiner',
      'an' => 'Determiner',
      'this' => 'Determiner',
      'these' => 'Determiner',
      'that' => 'Determiner',
      'from' => 'Preposition',
      'to' => 'Preposition',
      'on' => 'Preposition',
      'near' => 'Preposition'
    }
  end

  # Highly simplified tokenizer implementation.
  def tokenizer_l0(aText, aGrammar)
    tokens = aText.scan(/\S+/).map do |word|
      term_name = lexicon_l0[word]
      if term_name.nil?
        raise StandardError, "Word '#{word}' not found in lexicon"
      end
      terminal = aGrammar.name2symbol[term_name]
      Rley::Lexical::Token.new(word, terminal)
    end

    return tokens
  end
end # module
# End of file
