define 'kryptnostic.search-indexing-service', [
  'require'
  'bluebird'
  'kryptnostic.chunking.strategy.json'
  'kryptnostic.crypto-service-loader'
  'kryptnostic.object-search-key-api'
  'kryptnostic.kryptnostic-object'
  'kryptnostic.logger'
  'kryptnostic.metadata-api'
  'kryptnostic.metadata-request'
  'kryptnostic.kryptnostic-engine' #MOCK#
  'kryptnostic.search-key-serializer'
  'kryptnostic.search.indexer'
  'kryptnostic.search.metadata-mapper'
  'kryptnostic.sharing-client'
  'kryptnostic.indexed-metadata'
  'kryptnostic.search-credential-service' #added to load the keys stored
  'kryptnostic.kryptnostic-engine-provider'
], (require) ->

  Promise                   = require 'bluebird'

  CryptoServiceLoader       = require 'kryptnostic.crypto-service-loader'
  DocumentSearchKeyApi      = require 'kryptnostic.document-search-key-api'
  IndexedMetadata           = require 'kryptnostic.indexed-metadata'
  JsonChunkingStrategy      = require 'kryptnostic.chunking.strategy.json'
  KryptnosticObject         = require 'kryptnostic.kryptnostic-object'
  Logger                    = require 'kryptnostic.logger'
  MetadataApi               = require 'kryptnostic.metadata-api'
  MetadataMapper            = require 'kryptnostic.search.metadata-mapper'
  MetadataRequest           = require 'kryptnostic.metadata-request'
  KryptnosticEngine         = require 'kryptnostic.kryptnostic-engine'
  ObjectIndexer             = require 'kryptnostic.search.indexer'
  SearchKeySerializer       = require 'kryptnostic.search-key-serializer'
  SharingClient             = require 'kryptnostic.sharing-client'
  SearchCredentialService   = require 'kryptnostic.search-credential-service'
  KryptnosticEngineProvider = require 'kryptnostic.kryptnostic-engine-provider'

  log = Logger.get('SearchIndexingService')

  #
  # Handles indexing and submission of indexed metadata for StorageRequests.
  # Author: rbuckheit
  #
  class SearchIndexingService

    constructor : ->
      @cryptoServiceLoader  = new CryptoServiceLoader()
      @objectSearchKeyApi   = new ObjectSearchKeyApi()
      @metadataApi          = new MetadataApi()
      @metadataMapper       = new MetadataMapper()
      @objectIndexer        = new ObjectIndexer()
      @searchKeySerializer  = new SearchKeySerializer()
      @sharingClient        = new SharingClient()

    # indexes and uploads the submitted object.
    submit: ({ id, storageRequest }) ->
      unless storageRequest.isSearchable
        log.info('skipping non-searchable object', { id })
        return Promise.resolve()

      { body } = storageRequest
      { objectAddressMatrix, objectSearchKey, objectIndexPair } = {}

      Promise.resolve()
      .then =>
        engine = KryptnosticEngineProvider.getEngine()
        objectAddressMatrix = engine.getObjectAddressMatrix()
        objectSearchKey     = engine.getObjectSearchKey()
        objectIndexPair     = engine.getObjectIndexPair({ objectSearchKey, objectAddressMatrix })

        encryptedAddressFunction = @searchKeySerializer.encrypt(objectAddressMatrix)
        @objectSearchKeyApi.uploadAddressMatrix(id, encryptedAddressFunction)
      .then =>
        @objectSearchKeyApi.uploadSharingPair(id, objectIndexPair)
      .then =>
        @objectIndexer.index(id, body)
      .then (metadata) =>
        @prepareMetadataRequest({ id, metadata, objectAddressMatrix, objectSearchKey })
      .then (metadataRequest) =>
        @metadataApi.uploadMetadata( metadataRequest )

    # currently produces a single request, batch later if needed.
    prepareMetadataRequest: ({ id, metadata, objectAddressMatrix, objectSearchKey }) ->
      Promise.resolve()
      .then =>
        @cryptoServiceLoader.getObjectCryptoService(id, { expectMiss : false })
      .then (cryptoService) =>
        keyedMetadata = @metadataMapper.mapToKeys({
          metadata, objectAddressMatrix, objectSearchKey
        })

        metadataIndex = []
        for key, metadata of keyedMetadata
          body = metadata

          # encrypt metadata
          kryptnosticObject = KryptnosticObject.createFromDecrypted({ id, body })
          kryptnosticObject.setChunkingStrategy(JsonChunkingStrategy.URI)
          encrypted = kryptnosticObject.encrypt(cryptoService)
          encrypted.validateEncrypted()

          # format request
          data = encrypted.body
          _.extend(data, { key: id, strategy: { '@class': JsonChunkingStrategy.URI } })
          indexedMetadata = new IndexedMetadata { key, data , id }
          metadataIndex.push(indexedMetadata)

        return new MetadataRequest { metadata : metadataIndex }

  return SearchIndexingService
