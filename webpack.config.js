var fs = require('fs');
var ExtractTextPlugin = require('extract-text-webpack-plugin');

module.exports = {
  entry: [
    './html/elm-dice.js',
    './html/index.html',
    './html/elm-dice.css',
  ].concat(fs.readdirSync('./html/favicons').map(function(file) {
    return './html/favicons/' + file.toString();
  })),

  output: {
    path: './dist',
    filename: 'elm-dice.js'
  },

  resolve: {
    modulesDirectories: ['node_modules'],
    extensions: ['', '.js', '.elm']
  },

  module: {
    loaders: [
      {
        test: /\.(html|woff2|png|xml|ico|svg|json)$/,
        exclude: /node_modules/,
        loader: 'file?context=html&name=[path][name].[ext]'
      },
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        loader: 'elm-webpack'
      },
      {
        test: /\.css$/,
        loader: ExtractTextPlugin.extract('css-loader?importLoaders=1!postcss-loader'
        )
      }
    ],

    // noParse: /\.elm$/
  },

  plugins: [
    new ExtractTextPlugin('elm-dice.css', { allowChunks: true }),
  ],

  postcss: function(webpack) {
    return [
      require('autoprefixer')({ browsers: ['last 10 versions'] }),
      require('postcss-partial-import')({
        addDependencyTo: webpack,
        prefix: '',
        extension: '',
      })
    ];
  },

  devServer: {
    inline: true,
    stats: 'errors-only',
    contentBase: './html'
  }
};

