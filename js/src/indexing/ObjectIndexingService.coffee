define 'kryptnostic.indexing.object-indexing-service', [
  'require',
  'bluebird',
  'forge',
  'kryptnostic.binary-utils',
  'kryptnostic.chunking.strategy.json',
  'kryptnostic.create-object-request',
  'kryptnostic.crypto-service-loader',
  'kryptnostic.hash-function',
  'kryptnostic.kryptnostic-engine',
  'kryptnostic.kryptnostic-engine-provider',
  'kryptnostic.kryptnostic-object',
  'kryptnostic.kryptnostic-workers-api',
  'kryptnostic.object-api',
  'kryptnostic.search-api',
  'kryptnostic.sharing-api',
  'kryptnostic.validators'
], (require) ->

  # libraries
  Promise = require 'bluebird'
  forge = require 'forge'

  # APIs
  ObjectApi  = require 'kryptnostic.object-api'
  SearchApi  = require 'kryptnostic.search-api'
  SharingApi = require 'kryptnostic.sharing-api'

  # kryptnostic
  CreateObjectRequest       = require 'kryptnostic.create-object-request'
  CryptoServiceLoader       = require 'kryptnostic.crypto-service-loader'
  JsonChunkingStrategy      = require 'kryptnostic.chunking.strategy.json'
  KryptnosticEngine         = require 'kryptnostic.kryptnostic-engine'
  KryptnosticEngineProvider = require 'kryptnostic.kryptnostic-engine-provider'
  KryptnosticObject         = require 'kryptnostic.kryptnostic-object'
  KryptnosticWorkersApi     = require 'kryptnostic.kryptnostic-workers-api'
  ObjectIndexer             = require 'kryptnostic.indexing.object-indexer'

  # utils
  BinaryUtils  = require 'kryptnostic.binary-utils'
  HashFunction = require 'kryptnostic.hash-function'
  Validators   = require 'kryptnostic.validators'

  # constants
  BATCH_SIZE = 10000
  MINIMUM_TOKEN_LENGTH = 1

  { validateVersionedObjectKey } = Validators

  class ObjectIndexingService

    # defined in com.kryptnostic.v2.storage.types.TypeUUIDs
    @INDEX_SEGMENT_TYPE_ID = '00000000-0000-0000-0000-000000000007'

    constructor: ->
      @cryptoServiceLoader = new CryptoServiceLoader()
      @objectIndexer       = new ObjectIndexer()
      @objectApi           = new ObjectApi()
      @sharingApi          = new SharingApi()

    enqueueIndexTask: (data, objectKey, parentObjectKey) ->

      if not validateVersionedObjectKey(objectKey)
        return

      if not validateVersionedObjectKey(parentObjectKey)
        parentObjectKey = objectKey

      Promise.resolve(
        @sharingApi.getObjectSearchPair(parentObjectKey)
      )
      .then (objectSearchPair) =>
        if not KryptnosticEngine.isValidObjectSearchPair(objectSearchPair)
          engine = KryptnosticEngineProvider.getEngine()
          objectSearchPair = engine.generateObjectSearchPair()
          @sharingApi.addObjectSearchPair(parentObjectKey, objectSearchPair)
      .then =>
        Promise.resolve(
          KryptnosticWorkersApi.queryWebWorker(
            KryptnosticWorkersApi.OBJ_INDEXING_WORKER,
            {
              operation: 'index',
              params: {
                data,
                objectKey,
                parentObjectKey
              }
            }
          )
        )
        .catch (e) =>
          @index(data, objectKey, parentObjectKey)

        # we don't need to wait for the query Promise to resolve since we want to index in the background
        return

    index: (data, objectKey, parentObjectKey) ->

      if not validateVersionedObjectKey(objectKey)
        return Promise.resolve()

      if not validateVersionedObjectKey(parentObjectKey)
        parentObjectKey = objectKey

      # 1. tokenize the data, and build the list of inverted index segments
      invertedIndexSegments = @objectIndexer.buildInvertedIndexSegments(data, objectKey, parentObjectKey)

      # 2. randomly shuffle the inverted index segments
      @shuffle(invertedIndexSegments)

      # 3 split the inverted index segments into batches for uploading in bulk
      batchedInvertedIndexSegments = _.chunk(invertedIndexSegments, BATCH_SIZE)

      # 4. reserve a range of integers for each inverted index segment
      Promise.props({
        objectSearchPair: @sharingApi.getObjectSearchPair(parentObjectKey),
        objectCryptoService: @cryptoServiceLoader.getObjectCryptoService(parentObjectKey),
        segmentRangeStartIndex: SearchApi.reserveSegmentRange(parentObjectKey, invertedIndexSegments.length)
      })
      .then ({ objectSearchPair, objectCryptoService, segmentRangeStartIndex }) =>

        # we can't do anything if we don't have the object crypto service
        if not objectCryptoService
          return

        # 5. calculate the objectIndexPair from the objectSearchPair
        pairs = @calculateObjectIndexPairAndObjectSearchPair(parentObjectKey, objectSearchPair)
        objectIndexPair = pairs.objectIndexPair
        objectSearchPair = pairs.objectSearchPair

        # 6. loop over each inverted index segment in each batch
        _.forEach(batchedInvertedIndexSegments, (batch, batchIndex) =>

          indexSegmentRequests = []
          _.forEach(batch, (segment, segmentIndex) =>

            # we need the inverted index segment's position in the entire list of inverted index segments
            segmentIndexInRange = (batchIndex * BATCH_SIZE) + segmentIndex

            # 6.1 compute the SHA-256 hash of the segment's address
            segmentAddressHash = @computeSegmentAddressHash(
              segment.token,
              segmentRangeStartIndex,
              segmentIndexInRange,
              objectIndexPair
            )

            # the address hash could be null if we decide to not index the token
            if segmentAddressHash

              # 6.2 encrypt the inverted index segment
              encryptedSegment = @encryptInvertedIndexSegment(segment, parentObjectKey, objectCryptoService)

              # ToDo - create a IndexSegmentRequest class
              indexSegmentRequests.push({
                address: segmentAddressHash,
                contents: encryptedSegment
              })
          )

          # 7. store this batch of encrypted inverted index segments
          @objectApi.createIndexSegments(parentObjectKey, indexSegmentRequests)

          # done with this batch of inverted index segments
          return
        )

        # done with all inverted index segments
        return

      return

    createInvertedIndexSegmentObject: (segmentAddressHash, objectKey, parentObjectKey) ->

      createObjectRequest = new CreateObjectRequest({
        type: ObjectIndexingService.INDEX_SEGMENT_TYPE_ID,
        parentObjectId: parentObjectKey,
      })

      # ToDo - create a CreateIndexSegmentRequest class
      createIndexSegmentRequest = {
        address : segmentAddressHash,
        createObjectRequest : createObjectRequest
      }

      Promise.resolve(
        @objectApi.createIndexSegment(createIndexSegmentRequest)
      )
      .then (objectKeyForNewlyCreatedObject) ->
        return objectKeyForNewlyCreatedObject

    encryptInvertedIndexSegment: (invertedIndexSegment, objectKey, objectCryptoService) ->

      #
      # ToDo - generic object encryption/decryption
      #
      # kryptnosticObject = KryptnosticObject.createFromDecrypted({
      #   id: objectKey.objectId,
      #   body: invertedIndexSegment
      # })
      # kryptnosticObject.setChunkingStrategy(JsonChunkingStrategy.URI)
      # encrypted = kryptnosticObject.encrypt(objectCryptoService)
      # return encrypted.body

      dataToEncrypt = JSON.stringify(invertedIndexSegment)
      encryptedData = objectCryptoService.encrypt(dataToEncrypt)
      return encryptedData

    computeSegmentAddressHash: (segmentToken, segmentRangeStartIndex, segmentIndex, objectIndexPair) ->

      if not _.isString(segmentToken) or segmentToken.length <= MINIMUM_TOKEN_LENGTH
        return null

      # token -> 128-bit hash -> Uint8Array
      tokenHash = HashFunction.SHA_256_TO_128(segmentToken)
      tokenAsUint8 = BinaryUtils.stringToUint8(tokenHash)

      # compute address of token
      engine = KryptnosticEngineProvider.getEngine()
      addressAsUint8 = engine.calculateMetadataAddress(objectIndexPair, tokenAsUint8)

      # segment offset -> Uint8Array
      segmentOffset = segmentRangeStartIndex + segmentIndex
      segmentOffsetAsUint8 = BinaryUtils.intToUint8(segmentOffset)

      # concatenate the segment offset to the address
      segmentAddressAsUint8 = new Uint8Array(addressAsUint8.byteLength + segmentOffsetAsUint8.byteLength)
      segmentAddressAsUint8.set(new Uint8Array(addressAsUint8), 0)
      segmentAddressAsUint8.set(new Uint8Array(segmentOffsetAsUint8), addressAsUint8.byteLength)

      # SHA-256 hash the address
      segmentAddressAsForgeBuffer = new forge.util.ByteBuffer(segmentAddressAsUint8)
      segmentAddressHash = HashFunction.SHA_256(segmentAddressAsForgeBuffer.getBytes())
      segmentAddressHashAsBase64 = btoa(segmentAddressHash)

      return segmentAddressHashAsBase64

    #
    # calculate the objectIndexPair from the given objectSearchPair. if the objectSearchPair is not given,
    # calculate both the objectIndexPair and the objectSearchPair, and additionally, upload the newly-calculated
    # objectSearchPair
    #
    # @param VersionedObjectKey parentObjectKey
    # @param Uint8Array objectSearchPair
    #
    # @return Uint8Array objectIndexPair
    #
    calculateObjectIndexPairAndObjectSearchPair: (parentObjectKey, objectSearchPair) ->

      objectIndexPair = null
      engine = KryptnosticEngineProvider.getEngine()

      if not KryptnosticEngine.isValidObjectSearchPair(objectSearchPair)
        objectIndexPair = engine.generateObjectIndexPair()
        objectSearchPair = engine.calculateObjectSearchPairFromObjectIndexPair(objectIndexPair)
        @sharingApi.addObjectSearchPair(parentObjectKey, objectSearchPair)
      else
        objectIndexPair = engine.calculateObjectIndexPairFromObjectSearchPair(objectSearchPair)

      return { objectIndexPair, objectSearchPair }

    #
    # generates a random permutation of the given set of data, following the Fisher–Yates (Knuth) shuffle algorithm
    # https://en.wikipedia.org/wiki/Fisher-Yates_shuffle
    #
    shuffle: (data) ->
      currentIndex = data.length
      while (currentIndex)
        webCrypto = window.crypto or window.msCrypto
        randomInt = webCrypto.getRandomValues(new Uint32Array(1))[0]
        randomFloat = randomInt / Math.pow(2, 32)
        randomIndex = Math.floor(randomFloat * currentIndex)
        currentIndex--
        currentElement = data[currentIndex]
        data[currentIndex] = data[randomIndex]
        data[randomIndex] = currentElement
      return data

  return ObjectIndexingService
