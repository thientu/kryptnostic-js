define 'kryptnostic.object-api', [
  'require'
  'axios'
  'bluebird'
  'kryptnostic.configuration'
  'kryptnostic.kryptnostic-object'
  'kryptnostic.logger'
  'kryptnostic.security-utils'
  'kryptnostic.object-metadata'
], (require) ->

  axios             = require 'axios'
  SecurityUtils     = require 'kryptnostic.security-utils'
  KryptnosticObject = require 'kryptnostic.kryptnostic-object'
  Logger            = require 'kryptnostic.logger'
  Config            = require 'kryptnostic.configuration'
  Promise           = require 'bluebird'
  ObjectMetadata    = require 'kryptnostic.object-metadata'

  objectUrl         = -> Config.get('servicesUrl') + '/object'

  log            = Logger.get('ObjectApi')

  DEFAULT_HEADER = { 'Content-Type' : 'application/json' }

  validateId = (id) ->
    if !id
      throw new Error 'missing or empty id'
    if !_.isString(id)
      throw new Error 'id must be a string'

  validateType = (type) ->
    if !type
      throw new Error 'missing or empty object type'

  #
  # HTTP calls for interacting with the /object endpoint of Kryptnostic Services.
  # Author: rbuckheit
  #
  class ObjectApi

    # get all object ids accessible to the user
    getObjectIds : ->
      Promise.resolve(axios(SecurityUtils.wrapRequest({
        url    : objectUrl()
        method : 'GET'
      })))
      .then (response) ->
        objectIds = response.data.data
        return objectIds

    # load a kryptnosticObject in encrypted form
    getObject : (id) ->
      validateId(id)

      Promise.resolve(axios(SecurityUtils.wrapRequest({
        url    : objectUrl() + '/' + id
        method : 'GET'
      })))
      .then (response) ->
        raw = response.data
        return KryptnosticObject.createFromEncrypted(raw)

    # load object metadata only without contents
    getObjectMetadata: (id) ->
      validateId(id)

      Promise.resolve(axios(SecurityUtils.wrapRequest({
        url    : objectUrl() + '/' + id + '/metadata'
        method : 'GET'
      })))
      .then (response) ->
        raw = response.data
        return new ObjectMetadata(raw)

    # get all object ids of a particular type
    getObjectIdsByType: (type) ->
      validateType(type)

      Promise.resolve(axios(SecurityUtils.wrapRequest({
        url    : objectUrl() + '/type/' + type
        method : 'GET'
      })))
      .then (response) ->
        objectIds = response.data
        return objectIds

    # create a pending object for a new object and return an id
    createPendingObject : (pendingRequest) ->
      pendingRequest.validate()

      Promise.resolve(axios(SecurityUtils.wrapRequest({
        url         : objectUrl() + '/'
        method      : 'PUT'
        headers     : _.clone(DEFAULT_HEADER)
        data        : JSON.stringify(pendingRequest)
      })))
      .then (response) ->
        id = response.data.data
        log.debug('created pending', { id })
        return id

    # create a pending object for an object which already exists
    createPendingObjectFromExisting : (id) ->
      validateId(id)

      Promise.resolve(axios(SecurityUtils.wrapRequest({
        url    : objectUrl() + '/' + id
        method : 'PUT'
      })))
      .then (response) ->
        log.debug('created pending from existing', { id })
        return response.data

    # adds an encrypted block to a pending object
    updateObject : (id, encryptableBlock) ->
      validateId(id)

      Promise.resolve(axios(SecurityUtils.wrapRequest({
        url         : objectUrl() + '/' + id
        method      : 'POST'
        headers     : _.clone(DEFAULT_HEADER)
        data        : JSON.stringify(encryptableBlock)
      })))
      .then (response) ->
        log.debug('submitted block', { id })

    # deletes an object
    deleteObject : (id) ->
      validateId(id)

      Promise.resolve(axios(SecurityUtils.wrapRequest({
        url         : objectUrl() + '/' + id
        method      : 'DELETE'
      })))
      .then (response) ->
        log.debug('deleted object', { id })

  return ObjectApi
