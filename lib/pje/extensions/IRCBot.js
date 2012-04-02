// Copyright (c) 2012, Mitchell Cooper

var VERSION = '1.0';

function _new (opts) {
    if (typeof opts != 'object') throw new TypeError('IRCBot expects object options');
    this.value = 'hello!';
    return this;
}

function _someFunction () {
    return this.value;
}
