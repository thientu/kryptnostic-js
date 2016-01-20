# coffeelint: disable=cyclomatic_complexity

define 'kryptnostic.object-api', [
  'require'
  'axios'
  'bluebird'
  'kryptnostic.block-ciphertext'
  'kryptnostic.configuration'
  'kryptnostic.kryptnostic-object'
  'kryptnostic.logger'
  'kryptnostic.requests'
  'kryptnostic.object-metadata'
  'kryptnostic.validators'
  'kryptnostic.object-tree-load-request'
], (require) ->

  axios                 = require 'axios'
  BlockCiphertext       = require 'kryptnostic.block-ciphertext'
  Requests              = require 'kryptnostic.requests'
  Logger                = require 'kryptnostic.logger'
  Config                = require 'kryptnostic.configuration'
  Promise               = require 'bluebird'
  ObjectMetadata        = require 'kryptnostic.object-metadata'
  ObjectMetadataTree    = require 'kryptnostic.object-metadata-tree'
  ObjectTreeLoadRequest = require 'kryptnostic.object-tree-load-request'
  validators            = require 'kryptnostic.validators'

  { validateId, validateUuid } = validators

  DEFAULT_HEADER = { 'Content-Type' : 'application/json' }

  logger = Logger.get('ObjectApi')

  objectUrl         = -> Config.get('servicesUrlV2') + '/object'
  objectsUrl        = -> objectUrl() + '/bulk'
  objectIdUrl       = (objectId) -> objectUrl() + '/id/' + objectId
  objectMetadataUrl = (objectId) -> objectIdUrl(objectId) + '/metadata'
  objectVersionUrl  = (objectId, objectVersion) -> objectIdUrl(objectId) + '/' + objectVersion
  objectLevelsUrl   = -> objectUrl() + '/levels'

  class ObjectApi

    getObjectIds : ->
      throw new Error('ObjectApi:getObjectIds() is not implemented')

    getObject: (objectId) ->

      if not validateUuid(objectId)
        return Promise.resolve(null)

      Promise.resolve(
        @getObjects([objectId])
      )
      .then (objects) ->
        return objects[objectId]

    getObjects: (objectIds) ->

      if not validateUuids(objectIds)
        return Promise.resolve(null)

      Promise.resolve(
        axios(
          Requests.wrapCredentials({
            method  : 'POST'
            url     : objectsUrl()
            data    : JSON.stringify(objectIds)
            headers : _.clone(DEFAULT_HEADER)
          })
        )
      )
      .then (axiosResponse) ->
        if axiosResponse? and axiosResponse.data?
          # axiosResponse.data == Map<java.util.UUID, com.kryptnostic.kodex.v1.crypto.ciphers.BlockCiphertext>
          return _.mapValues(axiosResponse.data, (blockCiphertext) ->
            try
              return new BlockCiphertext(blockCiphertext)
            catch e
              return null
          )
        else
          return null

    getLatestVersionedObjectKey: (objectId) ->

      if not validateUuid(objectId)
        return Promise.resolve(null)

      Promise.resolve(
        axios(
          Requests.wrapCredentials({
            method : 'GET'
            url    : objectIdUrl(objectId)
          })
        )
      )
      .then (axiosResponse) ->
        if axiosResponse? and axiosResponse.data?
          # axiosResponse.data == com.kryptnostic.v2.storage.models.VersionedObjectKey
          return axiosResponse.data;
        else
          return null

    getObjectMetadata: (objectId) ->

      if not validateUuid(objectId)
        return Promise.resolve(null)

      Promise.resolve(
        axios(
          Requests.wrapCredentials({
            method : 'GET'
            url    : objectMetadataUrl(objectId)
          })
        )
      )
      .then (axiosResponse) ->
        if axiosResponse? and axiosResponse.data?
          # axiosResponse.data == com.kryptnostic.v2.storage.models.ObjectMetadata
          return new ObjectMetadata(axiosResponse.data)
        else
          return null

    getObjectsByTypeAndLoadLevel: (objectIds, typeLoadLevels, loadDepth) ->

      objectTreeLoadRequest = new ObjectTreeLoadRequest({
        objectIds  : objectIds
        loadLevels : typeLoadLevels
        depth      : loadDepth
      })

      Promise.resolve(
        axios(
          Requests.wrapCredentials({
            method  : 'POST'
            url     : objectLevelsUrl()
            data    : JSON.stringify(objectTreeLoadRequest)
            headers : _.clone(DEFAULT_HEADER)
          })
        )
      )
      .then (axiosResponse) ->
        if axiosResponse? and axiosResponse.data?
          # axiosResponse.data == Map<java.util.UUID, com.kryptnostic.v2.storage.models.ObjectMetadataEncryptedNode>
          # return new ObjectMetadataTree(axiosResponse.data)
          return axiosResponse.data
        else
          return null

    createObject: (createObjectRequest) ->
      Promise.resolve(
        axios(
          Requests.wrapCredentials({
            method  : 'POST'
            url     : objectUrl()
            data    : JSON.stringify(createObjectRequest)
            headers : _.clone(DEFAULT_HEADER)
          })
        )
      )
      .then (axiosResponse) ->
        if axiosResponse? and axiosResponse.data?
          # axiosResponse.data == com.kryptnostic.v2.storage.models.VersionedObjectKey
          return axiosResponse.data
        else
          return null

    getObjectAsBlockCiphertext: (versionedObjectKey) ->
      Requests.getBlockCiphertextFromUrl(
        objectVersionUrl(versionedObjectKey.objectId, versionedObjectKey.objectVersion)
      )

    setObjectFromBlockCiphertext: (versionedObjectKey, blockCiphertext) ->
      Promise.resolve(
        axios(
          Requests.wrapCredentials({
            method  : 'PUT'
            url     : objectVersionUrl(versionedObjectKey.objectId, versionedObjectKey.objectVersion)
            data    : JSON.stringify(blockCiphertext)
            headers : _.clone(DEFAULT_HEADER)
          })
        )
      )
      .then (axiosResponse) ->
        if axiosResponse? and axiosResponse.data?
          return axiosResponse.data
        else
          return null

    # adds an encrypted block to a pending object
    updateObject : (id, encryptableBlock) ->
      validateId(id)

      Promise.resolve(axios(Requests.wrapCredentials({
        method  : 'POST'
        url     : objectUrl() + '/' + id
        data    : JSON.stringify(encryptableBlock)
        headers : _.clone(DEFAULT_HEADER)
      })))
      .then (response) ->
        logger.debug('submitted block', { id })

    deleteObject : (objectId) ->
      validateId(objectId)
      Promise.resolve(
        axios(
          Requests.wrapCredentials({
            method  : 'DELETE'
            url     : objectIdUrl(objectId)
            headers : _.clone(DEFAULT_HEADER)
          })
        )
      )
      .then (axiosResponse) ->
        logger.debug('deleted object', { objectId })

    deleteObjectTrees: (objectIds) ->
      Promise.resolve(
        axios(
          Requests.wrapCredentials({
            method  : 'DELETE'
            url     : objectUrl()
            data    : JSON.stringify(objectIds)
            headers : _.clone(DEFAULT_HEADER)
          })
        )
      )

  return ObjectApi
