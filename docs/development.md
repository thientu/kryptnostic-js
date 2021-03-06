# development

## tools

This project uses:

1. Bower and NPM for package management.
2. require.js for package management.
3. r.js optimizer for builds.
4. Karma and Jasmine for unit testing.

## setup

To set up, install node.js and npm, then run the following from the main directory of `kryptnostic-js`:

```
sudo npm install -g bower
bower install
npm install
```

## conventions

1. Files exporting classes should be named in `UpperCamelCase` (one class per file).
2. Files exporting anything else should be named in `lower-kebab-case`.
3. AMD module definition names should be prefixed with `kryptnostic`, e.g. `kryptnostic.storage-client`
4. When using require for module definitions, prefer explicit `require(name)` calls to destructuring.

## sublime

Please use the `kryptnostic.sublime-project` sublime file when editing. This will automatically standardize whitespace and eliminate common style problems.

## building

Builds use the require.js optimizer, and produces `kryptnostic.js` in the `dist` directory.

```
npm run build
```

## unit testing

Karma and Jasmine are used for unit testing.

To start the unit tests, run:

```
npm run test
```

Tests named with the suffix `-test.coffee` will be picked up by the runner automatically.

## browser testing

For an end-to-end demo, build using `build.sh` then open `demo/index.html` in the browser.

## CORS

We're working to set up a build tool which will proxy requests to the backend from a single endpoint.
In the short-term, you'll get CORS errors when running from the local file `index.html` in development mode.
This is because the demo scripts attempt to access the multiple backend servers.

You can temporarily allow CORS in Chrome with the following command:

```
cd /Applications/ && open -a Google\ Chrome --args --disable-web-security
```
