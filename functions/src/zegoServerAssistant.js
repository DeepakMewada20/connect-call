"use strict";
exports.__esModule = true;
exports.generateToken04 = void 0;
var crypto_1 = require("crypto");

var ErrorCode;
(function (ErrorCode) {
    ErrorCode[ErrorCode["success"] = 0] = "success";
    ErrorCode[ErrorCode["appIDInvalid"] = 1] = "appIDInvalid";
    ErrorCode[ErrorCode["userIDInvalid"] = 3] = "userIDInvalid";
    ErrorCode[ErrorCode["secretInvalid"] = 5] = "secretInvalid";
    ErrorCode[ErrorCode["effectiveTimeInSecondsInvalid"] = 6] = "effectiveTimeInSecondsInvalid";
})(ErrorCode || (ErrorCode = {}));

function RndNum(a, b) {
    return Math.ceil((a + (b - a)) * Math.random());
}

function makeRandomIv() {
    var str = '0123456789abcdefghijklmnopqrstuvwxyz';
    var result = [];
    for (var i = 0; i < 16; i++) {
        var r = Math.floor(Math.random() * str.length);
        result.push(str.charAt(r));
    }
    return result.join('');
}

function getAlgorithm(keyBase64) {
    var key = Buffer.from(keyBase64);
    switch (key.length) {
        case 16:
            return 'aes-128-cbc';
        case 24:
            return 'aes-192-cbc';
        case 32:
            return 'aes-256-cbc';
    }
    throw new Error('Invalid key length: ' + key.length);
}

function aesEncrypt(plainText, key, iv) {
    var cipher = crypto_1.createCipheriv(getAlgorithm(key), key, iv);
    cipher.setAutoPadding(true);
    var encrypted = cipher.update(plainText);
    var final = cipher.final();
    var out = Buffer.concat([encrypted, final]);
    return Uint8Array.from(out).buffer;
}

/**
 * Official ZEGOCLOUD Token04 generation function
 * @param {number} appId - ZEGOCLOUD project AppID (integer)
 * @param {string} userId - User identifier (Firebase UID)
 * @param {string} secret - 32-byte ServerSecret
 * @param {number} effectiveTimeInSeconds - Validity duration in seconds
 * @param {string} payload - Optional payload (leave empty string for standard tokens)
 * @returns {string} Token string
 */
function generateToken04(appId, userId, secret, effectiveTimeInSeconds, payload) {
    if (!appId || typeof appId !== 'number') {
        throw {
            errorCode: ErrorCode.appIDInvalid,
            errorMessage: 'appID invalid'
        };
    }
    if (!userId || typeof userId !== 'string') {
        throw {
            errorCode: ErrorCode.userIDInvalid,
            errorMessage: 'userId invalid'
        };
    }
    if (!secret || typeof secret !== 'string' || secret.length !== 32) {
        throw {
            errorCode: ErrorCode.secretInvalid,
            errorMessage: 'secret must be a 32 byte string'
        };
    }
    if (!effectiveTimeInSeconds || typeof effectiveTimeInSeconds !== 'number') {
        throw {
            errorCode: ErrorCode.effectiveTimeInSecondsInvalid,
            errorMessage: 'effectiveTimeInSeconds invalid'
        };
    }

    var createTime = Math.floor(new Date().getTime() / 1000);
    var tokenInfo = {
        app_id: appId,
        user_id: userId,
        nonce: RndNum(-2147483648, 2147483647),
        ctime: createTime,
        expire: createTime + effectiveTimeInSeconds,
        payload: payload || ''
    };

    var plainText = JSON.stringify(tokenInfo);
    var iv = makeRandomIv();
    var encryptBuf = aesEncrypt(plainText, secret, iv);

    var b1 = new Uint8Array(8);
    var b2 = new Uint8Array(2);
    var b3 = new Uint8Array(2);

    new DataView(b1.buffer).setBigInt64(0, BigInt(tokenInfo.expire), false);
    new DataView(b2.buffer).setUint16(0, iv.length, false);
    new DataView(b3.buffer).setUint16(0, encryptBuf.byteLength, false);

    var buf = Buffer.concat([
        Buffer.from(b1),
        Buffer.from(b2),
        Buffer.from(iv),
        Buffer.from(b3),
        Buffer.from(encryptBuf),
    ]);

    var dv = new DataView(Uint8Array.from(buf).buffer);
    return '04' + Buffer.from(dv.buffer).toString('base64');
}

exports.generateToken04 = generateToken04;
