define 'soteria.tree-node', [
  'require'
  'bluebird'
  'lodash'
  'soteria.logger'
], (require) ->

  _       = require 'lodash'
  Promise = require 'bluebird'
  Logger  = require 'soteria.logger'

  log = Logger.get('TreeNode')

  validateId = (id) ->
    if _.isEmpty(id)
      throw new Error 'no root id provided'

  validateChildren = (children) ->
    unless _.isArray(children)
      throw new Error 'children must be an array'
    children.forEach (child) ->
      unless child.constructor.name is 'TreeNode'
        throw new Error 'child must be a tree node'

  #
  # Represents a node in a tree of Kryptnostic objects.
  # Author: rbuckheit
  #
  class TreeNode

    constructor: (@id, @children = []) ->
      log.info('construct', {@id, @children})

      validateId(@id)
      validateChildren(@children)

    # visits children depth-first and then the root note.
    visit : (visitor) ->
      log.info('visit root')
      Promise.all(_.map(@children, (child) ->
        log.info('visit child', child)
        return child.visit(visitor)
      ))
      .then =>
        log.info('visit', @id)
        return visitor.visit(@id)

  return TreeNode
