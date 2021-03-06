(
  {
    baseUrl                : 'js/src',
    name                   : 'cs!kryptnostic',
    out                    : 'dist/kryptnostic.js',
    optimize               : 'none',
    waitSeconds            : 1000000,
    wrap                   : false,
    findNestedDependencies : true,
    paths                  : {
      'axios'         : '../../bower_components/axios/dist/axios.min',
      'base64'        : '../../bower_components/base64/base64',
      'bluebird'      : '../../bower_components/bluebird/js/browser/bluebird',
      'forge'         : '../../bower_components/forge/js/forge.min',
      'function-name' : '../../bower_components/function-name/index',
      'jscache'       : '../../bower_components/jscache/index',
      'lodash'        : '../../bower_components/lodash/lodash',
      'loglevel'      : '../../bower_components/loglevel/dist/loglevel',
      'murmurhash3'   : '../../bower_components/murmurhash3/index',
      'pako'          : '../../node_modules/pako/dist/pako',
      'require'       : '../../bower_components/requirejs/require',
      'revalidator'   : '../../node_modules/revalidator/lib/revalidator'
    },
    preserveLicenseComments: false,
    // these dependencies are used in the build process but not in the dist.
    exclude  : [ 'cs', 'coffee-script' ],
    packages : [
      {
        name     : 'cs',
        location : '../../bower_components/require-cs',
        main     : 'cs'
      },
      {
        name     : 'coffee-script',
        location : '../../bower_components/coffeescript',
        main     : 'extras/coffee-script'
      }
    ]
  }
)
