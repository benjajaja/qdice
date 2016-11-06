module.exports = {
  entry: './html/index.js',

  output: {
    path: './dist',
    filename: 'index.js'
  },

  resolve: {
    modulesDirectories: ['node_modules'],
    extensions: ['', '.js', '.elm']
  },

  module: {
    loaders: [
      {
        test: /\.html$/,
        exclude: /node_modules/,
        loader: 'file?name=[name].[ext]'
      },
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/, /Stylesheets.elm/],
        loader: 'elm-webpack'
      },
      {
        test: /Stylesheets\.elm$/,
        loader: "style!css!elm-css-webpack"
      },
      {
        test: /\.css$/,
        loader: "style!css"
      }
    ],

    // noParse: /\.elm$/
  },

  devServer: {
    inline: true,
    stats: 'errors-only'
  }
};

