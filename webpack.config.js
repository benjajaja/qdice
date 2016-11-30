var ExtractTextPlugin = require('extract-text-webpack-plugin');

module.exports = {
  entry: './html/elm-dice.js',

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
        test: /\.(html)$/,
        exclude: /node_modules/,
        loader: 'file?name=[name].[ext]'
      },
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        loader: 'elm-webpack'
      },
      {
        test: /\.css$/,
        loader: ExtractTextPlugin.extract('css-loader?importLoaders=1!postcss-loader'
            // ].join('!') 
        )
      }
    ],

    // noParse: /\.elm$/
  },

  plugins: [
    new ExtractTextPlugin('elm-dice.css', { allowChunks: true }),
  ],

  postcss: [
    require('autoprefixer')({ browsers: ['last 200 versions'] }),
  ],

  devServer: {
    inline: true,
    stats: 'errors-only',
    contentBase: './html'
  }
};

