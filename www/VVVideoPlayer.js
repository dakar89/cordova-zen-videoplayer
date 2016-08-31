var exec = require('cordova/exec');

exports.startPlayer = function(url, playPosition, success, error) {
    exec(success, error, "VVVideoPlayer", "startPlayer", [url, playPosition || 0]);
};

// exports.play = function(arg0, success, error) {
//     exec(success, error, "VVVideoPlayer", "play", [arg0]);
// };

// exports.onPlay = function(callback) {
//     exec(callback, null, "VVVideoPlayer", "onPlay", null);
// };

// exports.pause = function(success, error) {
//     exec(success, error, "VVVideoPlayer", "pause", null);
// };

// exports.onPause = function(callback) {
//     exec(callback, null, "VVVideoPlayer", "onPause", null);
// };

exports.stop = function() {
    exec(null, null, "VVVideoPlayer", "closePlayer", null);
};

exports.onPlaybackEnded = function(callback) {
    exec(callback, null, "VVVideoPlayer", "onPlaybackEnded", null);
};

exports.setCurrentTime = function(time) {
    exec(null, null, "VVVideoPlayer", "setCurrentTime", [time]);
};

exports.getCurrentTime = function(callback) {
    exec(callback, null, "VVVideoPlayer", "getCurrentTime", null);
};

exports.getDuration = function(callback) {
    exec(callback, null, "VVVideoPlayer", "getDuration", null);
};

exports.getCompletionPercentage = function(callback) {
    exec(callback, null, "VVVideoPlayer", "getCompletionPercentage", null);
};