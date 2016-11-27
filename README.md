[![Build Status](https://travis-ci.org/famished-tiger/Rley.svg?branch=master)](https://travis-ci.org/famished-tiger/Rley)
[![Coverage Status](https://img.shields.io/coveralls/famished-tiger/Rley.svg)](https://coveralls.io/r/famished-tiger/Rley?branch=master)
[![Gem Version](https://badge.fury.io/rb/rley.svg)](http://badge.fury.io/rb/rley)
[![Dependency Status](https://gemnasium.com/famished-tiger/Rley.svg)](https://gemnasium.com/famished-tiger/Rley)
[![Inline docs](http://inch-ci.org/github/famished-tiger/Rley.svg?branch=master)](http://inch-ci.org/github/famished-tiger/Rley)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](https://github.com/famished-tiger/Rley/blob/master/LICENSE.txt)


[Rley](https://github.com/famished-tiger/Rley)
======

A Ruby library for constructing general parsers for _any_ context-free languages.  


What is Rley?
-------------
__Rley__ uses the [Earley](http://en.wikipedia.org/wiki/Earley_parser)
algorithm which is a general parsing algorithm that can handle any context-free
grammar. Earley parsers can literally swallow anything that can be described
by such a context-free grammar. That's why Earley parsers find their place in so
many __NLP__ (_Natural Language Processing_) libraries/toolkits.  

In addition, __Rley__ goes beyond most Earley parser implementations by providing
support for ambiguous parses. Indeed, it delivers the results of a parse as a
_Shared Packed Parse Forest_ (SPPF). A SPPF is a data structure that allows to
encode efficiently all the possible parse trees that result from an ambiguous
grammar.  

As another distinctive mark, __Rley__ is also the first Ruby implementation of a
parsing library based on the new _Grammar Flow Graph_ approach (_TODO: add details_).

### What it can do?
Maybe parsing algorithms and internal implementation details are of lesser
interest to you and the good question to ask is "what Rley can really do?".  

In a nutshell:  
* Rley can parse context-free languages that other well-known libraries cannot
handle  
* Built-in support for ambiguous grammars that typically occur in NLP

In short, the foundations of Rley are strong enough to be useful in a large
application range such as:  
* computer languages,  
* artificial intelligence and  
* Natural Language Processing.

#### Features
* Simple API for context-free grammar definition,
* Allows ambiguous grammars,
* Generates shared packed parse forests,
* Accepts left-recursive rules/productions,
* Provides syntax error detection and reporting.

---

Getting Started
---------------

### Installation
Installing the latest stable version is simple:

    $ gem install rley


## A whirlwind tour of Rley
The purpose of this section is show how to create a parser for a minimalistic
English language subset. 
The tour is organized into the following steps:  
1. [Defining the language grammar](#defining-the-language-grammar)  
2. [Creating a lexicon](#creating-a-lexicon)  
3. [Creating a tokenizer](#creating-a-tokenizer)  
4. [Building the parser](building-the-parser)  
5. [Parsing some input](#parsing-some-input)  
6. [Generating the parse forest](#generating-the-parse-forest)

The complete source code of the tour can be found in the 
[examples](https://github.com/famished-tiger/Rley/tree/master/examples/NLP/mini_en_demo.rb)
directory

### Defining the language grammar
The subset of English grammar is based on an example from the NLTK book.

```ruby  
    require 'rley'  # Load Rley library

    # Instantiate a builder object that will build the grammar for us
    builder = Rley::Syntax::GrammarBuilder.new

    # Next 2 lines we define the terminal symbols (=word categories in the lexicon)
    builder.add_terminals('Noun', 'Proper-Noun', 'Verb')
    builder.add_terminals('Determiner', 'Preposition')

    # Here we define the productions (= grammar rules)
    builder.add_production('S' => %w[NP VP])
    builder.add_production('NP' => 'Proper-Noun')
    builder.add_production('NP' => %w[Determiner Noun])
    builder.add_production('NP' => %w[Determiner Noun PP])
    builder.add_production('VP' => %w[Verb NP])
    builder.add_production('VP' => %w[Verb NP PP])
    builder.add_production('PP' => %w[Preposition NP])

    # And now, let's build the grammar...
    grammar = builder.grammar
```  

## Creating a lexicon

```ruby
    # To simplify things, lexicon is implemented as a Hash with pairs of the form:
    # word => terminal symbol name
    Lexicon = {
      'man' => 'Noun',
      'dog' => 'Noun',
      'cat' => 'Noun',
      'telescope' => 'Noun',
      'park' => 'Noun',  
      'saw' => 'Verb',
      'ate' => 'Verb',
      'walked' => 'Verb',
      'John' => 'Proper-Noun',
      'Mary' => 'Proper-Noun',
      'Bob' => 'Proper-Noun',
      'a' => 'Determiner',
      'an' => 'Determiner',
      'the' => 'Determiner',
      'my' => 'Determiner',
      'in' => 'Preposition',
      'on' => 'Preposition',
      'by' => 'Preposition',
      'with' => 'Preposition'
    }
```  


## Creating a tokenizer
```ruby
    # A tokenizer reads the input string and converts it into a sequence of tokens
    # Highly simplified tokenizer implementation.
    def tokenizer(aText, aGrammar)
      tokens = aText.scan(/\S+/).map do |word|
        term_name = Lexicon[word]
        if term_name.nil?
          raise StandardError, "Word '#{word}' not found in lexicon"
        end
        terminal = aGrammar.name2symbol[term_name]
        Rley::Parser::Token.new(word, terminal)
      end

      return tokens
    end
```

## Building the parser
```ruby
  # Easy with Rley...
  parser = Rley::Parser::GFGEarleyParser.new(grammar)
```


## Parsing some input
```ruby
    input_to_parse = 'John saw Mary with a telescope'
    # Convert input text into a sequence of token objects...
    tokens = tokenizer(input_to_parse, grammar)
    result = parser.parse(tokens)

    puts "Parsing successful? #{result.success?}" # => Parsing successful? true
```

## Generating the parse forest
```ruby
    pforest = result.parse_forest
```



## Examples

The project source directory contains several example scripts that demonstrate 
how grammars are to be constructed and used.


## Other similar Ruby projects
__Rley__ isn't the sole implementation of the Earley parser algorithm in Ruby.  
Here are a few other ones:  
- [Kanocc gem](https://rubygems.org/gems/kanocc) -- Advertised as a Ruby based parsing and translation framework.  
  Although the gem dates from 2009, the author still maintains its in a public repository in [Github](https://github.com/surlykke/Kanocc)  
  The grammar symbols (tokens and non-terminals) must be represented as (sub)classes.
  Grammar rules are methods of the non-terminal classes. A rule can have a block code argument
  that specifies the semantic action when that rule is applied.  
- [lc1 project](https://github.com/kp0v/lc1) -- Advertised as a combination of Earley and Viterbi algorithms for [Probabilistic] Context Free Grammars   
  Aimed in parsing brazilian portuguese.  
  [earley project](https://github.com/joshingly/earley) -- An Earley parser (grammar rules are specified in JSON format).  
  The code doesn't seem to be maintained: latest commit dates from Nov. 2011.  
- [linguist project](https://github.com/davidkellis/linguist) -- Advertised as library for parsing context-free languages.  
  It is a recognizer not a parser. In other words it can only tell whether a given input
  conforms to the grammar rules or not. As such it cannot build parse trees.  
  The code doesn't seem to be maintained: latest commit dates from Oct. 2011.


##  Thanks to:
* Professor Keshav Pingali, one of the creators of the Grammar Flow Graph parsing approach for his encouraging e-mail exchanges.

---

Copyright
---------
Copyright (c) 2014-2016, Dimitri Geshef.  
__Rley__ is released under the MIT License see [LICENSE.txt](https://github.com/famished-tiger/Rley/blob/master/LICENSE.txt) for details.
