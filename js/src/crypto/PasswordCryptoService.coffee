define 'kryptnostic.password-crypto-service', [
  'require',
  'forge',
  'kryptnostic.abstract-crypto-service'
], (require) ->
  'use strict'

  Forge                 = require 'forge'
  AbstractCryptoService = require 'kryptnostic.abstract-crypto-service'
  BlockCiphertext       = require 'kryptnostic.block-ciphertext'

  DEFAULT_ALGORITHM     = 'AES'
  DEFAULT_MODE          = 'CTR'

  derive = (password, salt, iterations, keySize) ->
    md = Forge.sha1.create()
    return Forge.pkcs5.pbkdf2(password, salt, iterations, keySize, md)

  class PasswordCryptoService

    #
    # HACK!!! - uglfifying changes constructor.name, so we can't rely on the name property
    #
    _CLASS_NAME: 'PasswordCryptoService'
    @_CLASS_NAME: 'PasswordCryptoService'

    @BLOCK_CIPHER_ITERATIONS : 128

    @BLOCK_CIPHER_KEY_SIZE   : 16

    constructor: ->
      @abstractCryptoService = new AbstractCryptoService({
        algorithm : DEFAULT_ALGORITHM,
        mode      : DEFAULT_MODE
      })

    encrypt: (plaintext, password) ->
      blockCipherKeySize    = PasswordCryptoService.BLOCK_CIPHER_KEY_SIZE
      blockCipherIterations = PasswordCryptoService.BLOCK_CIPHER_ITERATIONS

      salt     = Forge.random.getBytesSync(blockCipherKeySize)
      key      = derive(password, salt, blockCipherIterations, blockCipherKeySize)
      iv       = Forge.random.getBytesSync(blockCipherKeySize)
      contents = @abstractCryptoService.encrypt(key, iv, plaintext)

      return new BlockCiphertext {
        contents : btoa(contents)
        iv       : btoa(iv)
        salt     : btoa(salt)
      }

    decrypt: (blockCiphertext, password) ->
      blockCipherKeySize    = PasswordCryptoService.BLOCK_CIPHER_KEY_SIZE
      blockCipherIterations = PasswordCryptoService.BLOCK_CIPHER_ITERATIONS

      salt     = atob(blockCiphertext.salt)
      key      = derive(password, salt, blockCipherIterations, blockCipherKeySize)
      iv       = atob(blockCiphertext.iv)
      contents = atob(blockCiphertext.contents)

      return @abstractCryptoService.decrypt(key, iv, contents)

    _derive: (password, salt, iterations, keySize) ->
      return derive(password, salt, iterations, keySize)

  return PasswordCryptoService
