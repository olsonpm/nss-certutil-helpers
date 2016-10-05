'use strict';


//---------//
// Imports //
//---------//

const bPromise = require('bluebird')
  , bFs = bPromise.promisifyAll(require('fs'))
  , chalk = require('chalk')
  , https = require('https')
  , portfinder = require('portfinder')
  ;


//------//
// Init //
//------//

const bGetPort = bPromise.promisify(portfinder.getPort)
  , highlight = chalk.green
  , log = console.log
  ;


//------//
// Main //
//------//

bPromise.props({
    serverPort: bGetPort()
    // pfx is synonymous with p12
    , pfx: bFs.readFileAsync('./test-server-nick.p12')
  })
  .then(({ serverPort, pfx }) => {
    https.createServer({
        requestCert: true
        , rejectUnauthorized: true
        , pfx
      }
      , (req, res) => {
        res.end('can I get a "woo!" for mutual ssl authentication?');
      })
      .listen(serverPort);

    log('node server listening on port ' + highlight(serverPort));
  });
