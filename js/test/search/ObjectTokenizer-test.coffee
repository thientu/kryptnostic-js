define [
  'require'
  'kryptnostic.search.tokenizer'
], (require) ->

  ObjectTokenizer = require 'kryptnostic.search.tokenizer'

  describe 'ObjectTokenizer', ->

    describe '#analyze', ->

      it 'should produce an inverted index of words', ->
        source = 'anderson reservoir bass are the best bass'
        expectedIndex = {
          anderson  : [ 0 ]
          reservoir : [ 9 ]
          bass      : [ 19, 37 ]
          are       : [ 24 ]
          the       : [ 28 ]
          best      : [ 32 ]
        }
        expect(ObjectTokenizer.analyze(source)).toEqual(expectedIndex)

      it 'should not index punctuation or special characters', ->
        source = 'foo .#~ $%! bar @*()-=_+ []/<>;"| }{ ~`,.'
        expectedIndex = {
          foo : [ 0 ]
          bar : [ 12 ]
        }
        expect(ObjectTokenizer.analyze(source)).toEqual(expectedIndex)

      it 'should produce empty index for empty string', ->
        expect(ObjectTokenizer.analyze('')).toEqual({})

      it 'should throw for non-string sources', ->
        notStrings = [ undefined, null, {}, 0, /regex/ ]
        notStrings.forEach (source) ->
          expect( -> ObjectTokenizer.analyze(source) ).toThrow()

