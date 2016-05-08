//
//  watch and build
//
var exec = require('child_process').exec;
var chokidar = require('chokidar');
var historyApiFallback = require('connect-history-api-fallback');

var source_paths = ["src/*.elm", "src/*/*.elm", "src/Native/*.js", "src/*/Native/*.js"];

chokidar.watch(source_paths, {ignored: /[\/\\]\./, ignoreInitial: true}).on('all', function(event, path) {

    // clear the terminal
    process.stdout.write('\u001B[2J\u001B[0;0f');

    // run the Elm compiler
    exec("cd src && elm-make Main.elm --output=../public/main.js --yes", function(err, stdout, stderr){
        if (err) console.log(stderr);
        else console.log(stdout);
    });
});


//
//  browser sync
//
var browserSync = require('browser-sync');

browserSync({
    server: "public",
    files: ["public/*"],
    port: 8001,
    open: false,
    notify: false,
    middleware: [ historyApiFallback() ]
});