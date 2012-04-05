Highlighter = require 'highlighter'
Buffer = require 'buffer'
Range = require 'range'

describe "Highlighter", ->
  [highlighter, buffer] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    highlighter = new Highlighter(buffer)

  describe "constructor", ->
    it "tokenizes all the lines in the buffer", ->
      expect(highlighter.lineForScreenRow(0).tokens[0]).toEqual(type: 'keyword.definition', value: 'var')
      expect(highlighter.lineForScreenRow(11).tokens[1]).toEqual(type: 'keyword', value: 'return')

  describe "when the buffer changes", ->
    changeHandler = null

    beforeEach ->
      changeHandler = jasmine.createSpy('changeHandler')
      highlighter.on "change", changeHandler

    describe "when lines are updated, but none are added or removed", ->
      it "updates tokens for each of the changed lines", ->
        range = new Range([0, 0], [2, 0])
        buffer.change(range, "foo()\nbar()\n")

        expect(highlighter.lineForScreenRow(0).tokens[0]).toEqual(type: 'identifier', value: 'foo')
        expect(highlighter.lineForScreenRow(1).tokens[0]).toEqual(type: 'identifier', value: 'bar')

        # line 2 is unchanged
        expect(highlighter.lineForScreenRow(2).tokens[1]).toEqual(type: 'keyword', value: 'if')

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]

        expect(event.oldRange).toEqual range
        expect(event.newRange).toEqual new Range([0, 0], [2,0])

      it "updates tokens for lines beyond the changed lines if needed", ->
        buffer.insert([5, 30], '/* */')
        changeHandler.reset()

        buffer.insert([2, 0], '/*')
        expect(highlighter.lineForScreenRow(3).tokens[0].type).toBe 'comment'
        expect(highlighter.lineForScreenRow(4).tokens[0].type).toBe 'comment'
        expect(highlighter.lineForScreenRow(5).tokens[0].type).toBe 'comment'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual new Range([2, 0], [5, buffer.lineForRow(5).length])
        expect(event.newRange).toEqual new Range([2, 0], [5, buffer.lineForRow(5).length])

      it "resumes highlighting with the state of the previous line", ->
        buffer.insert([0, 0], '/*')
        buffer.insert([5, 0], '*/')

        buffer.insert([1, 0], 'var ')
        expect(highlighter.lineForScreenRow(1).tokens[0].type).toBe 'comment'

    describe "when lines are both updated and removed", ->
      it "updates tokens to reflect the removed lines", ->
        range = new Range([1, 0], [3, 0])
        buffer.change(range, "foo()")

        # previous line 0 remains
        expect(highlighter.lineForScreenRow(0).tokens[0]).toEqual(type: 'keyword.definition', value: 'var')

        # previous line 3 should be combined with input to form line 1
        expect(highlighter.lineForScreenRow(1).tokens[0]).toEqual(type: 'identifier', value: 'foo')
        expect(highlighter.lineForScreenRow(1).tokens[6]).toEqual(type: 'identifier', value: 'pivot')

        # lines below deleted regions should be shifted upward
        expect(highlighter.lineForScreenRow(2).tokens[1]).toEqual(type: 'keyword', value: 'while')
        expect(highlighter.lineForScreenRow(3).tokens[1]).toEqual(type: 'identifier', value: 'current')
        expect(highlighter.lineForScreenRow(4).tokens[3]).toEqual(type: 'keyword.operator', value: '<')

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual range
        expect(event.newRange).toEqual new Range([1, 0], [1, 5])

      it "updates tokens for lines beyond the changed lines if needed", ->
        buffer.insert([5, 30], '/* */')
        changeHandler.reset()

        buffer.change(new Range([2, 0], [3, 0]), '/*')
        expect(highlighter.lineForScreenRow(2).tokens[0].type).toBe 'comment'
        expect(highlighter.lineForScreenRow(3).tokens[0].type).toBe 'comment'
        expect(highlighter.lineForScreenRow(4).tokens[0].type).toBe 'comment'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual new Range([2, 0], [5, buffer.lineForRow(4).length])
        expect(event.newRange).toEqual new Range([2, 0], [4, buffer.lineForRow(4).length])

    describe "when lines are both updated and inserted", ->
      it "updates tokens to reflect the inserted lines", ->
        range = new Range([1, 0], [2, 0])
        buffer.change(range, "foo()\nbar()\nbaz()\nquux()")

        # previous line 0 remains
        expect(highlighter.lineForScreenRow(0).tokens[0]).toEqual(type: 'keyword.definition', value: 'var')

        # 3 new lines inserted
        expect(highlighter.lineForScreenRow(1).tokens[0]).toEqual(type: 'identifier', value: 'foo')
        expect(highlighter.lineForScreenRow(2).tokens[0]).toEqual(type: 'identifier', value: 'bar')
        expect(highlighter.lineForScreenRow(3).tokens[0]).toEqual(type: 'identifier', value: 'baz')

        # previous line 2 is joined with quux() on line 4
        expect(highlighter.lineForScreenRow(4).tokens[0]).toEqual(type: 'identifier', value: 'quux')
        expect(highlighter.lineForScreenRow(4).tokens[4]).toEqual(type: 'keyword', value: 'if')

        # previous line 3 is pushed down to become line 5
        expect(highlighter.lineForScreenRow(5).tokens[3]).toEqual(type: 'identifier', value: 'pivot')

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual range
        expect(event.newRange).toEqual new Range([1, 0], [4, 6])

      it "updates tokens for lines beyond the changed lines if needed", ->
        buffer.insert([5, 30], '/* */')
        changeHandler.reset()

        buffer.insert([2, 0], '/*\nabcde\nabcder')
        expect(highlighter.lineForScreenRow(2).tokens[0].type).toBe 'comment'
        expect(highlighter.lineForScreenRow(3).tokens[0].type).toBe 'comment'
        expect(highlighter.lineForScreenRow(4).tokens[0].type).toBe 'comment'
        expect(highlighter.lineForScreenRow(5).tokens[0].type).toBe 'comment'
        expect(highlighter.lineForScreenRow(6).tokens[0].type).toBe 'comment'
        expect(highlighter.lineForScreenRow(7).tokens[0].type).toBe 'comment'
        expect(highlighter.lineForScreenRow(8).tokens[0].type).not.toBe 'comment'

        expect(changeHandler).toHaveBeenCalled()
        [event] = changeHandler.argsForCall[0]
        expect(event.oldRange).toEqual new Range([2, 0], [5, buffer.lineForRow(7).length])
        expect(event.newRange).toEqual new Range([2, 0], [7, buffer.lineForRow(7).length])

  describe "when the buffer contains tab characters", ->
    beforeEach ->
      buffer = new Buffer(require.resolve('fixtures/sample-with-tabs.coffee'))
      highlighter = new Highlighter(buffer)

    it "always renders each tab as its own atomic token containing atom.tabText", ->
      screenLine0 = highlighter.lineForScreenRow(0)
      expect(screenLine0.text).toBe "# Econ 101#{atom.tabText}"
      { tokens } = screenLine0
      expect(tokens.length).toBe 2
      expect(tokens[0].value).toBe "# Econ 101"
      expect(tokens[1].value).toBe atom.tabText
      expect(tokens[1].type).toBe tokens[0].type
      expect(tokens[1].isAtomic).toBeTruthy()

      expect(highlighter.lineForScreenRow(2).text).toBe "#{atom.tabText} buy()#{atom.tabText}while supply > demand"
