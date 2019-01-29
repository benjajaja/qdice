var fs = require('fs');
var path = require('path');
var webpack = require('webpack');
var ExtractTextPlugin = require('extract-text-webpack-plugin');
var CopyWebpackPlugin = require('copy-webpack-plugin');
var HtmlWebpackPlugin = require('html-webpack-plugin');

function logEnv(env) {
  console.log('Parse webpack.config.js env.production: ' + env);
  return env;
}

module.exports = env => ({
  entry: [
    './html/elm-dice.js',
    './html/elm-dice.css',
  ],

  output: {
    path: path.join(__dirname, './dist'),
    filename: 'elm-dice.[hash].js'
  },

  resolve: {
    modules: [
      'node_modules',
      path.join(__dirname, "src"),
    ],
    extensions: ['.js', '.elm']
  },

  module: {
    rules: [
      {
        test: /\.(woff2|png|xml|ico|svg|json)$/,
        exclude: /node_modules/,
        use: [
          {
            loader: 'file-loader',
            options: {
              context: 'html',
              name: '[path][name].[ext]',
            },
          },
        ],
      },
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        use: {
          loader: 'elm-webpack-loader',
          options: {
            optimize: false,
          },
        },
      },
      {
        test: /\.css$/,
        use: ExtractTextPlugin.extract({
          fallback: 'style-loader',
          use: [
            { loader: 'css-loader', options: { importLoaders: 1 } },
            {
              loader: 'postcss-loader',
              options: {
                ident: 'postcss',
                plugins: function(loader) {
                  return [
                    require('autoprefixer')({ browsers: ['last 10 versions'] }),
                    require('postcss-partial-import')({
                      addDependencyTo: webpack,
                      prefix: '',
                      extension: '',
                    }),
                  ];
                },
              },
            },
          ],
        }),
      },
    ],
  },

  plugins: [
    new webpack.DefinePlugin({
      'process.env.NODE_ENV': '"production"'
    }),
    new ExtractTextPlugin("elm-dice.[hash].css"),
    new CopyWebpackPlugin([
      { from: 'html/manifest.json' },
      { from: 'html/favicons-2', to: 'favicons-2'},
      { from: 'html/favicon.ico' },
      { from: 'html/die.svg' },
      { from: 'html/board_header.svg' },
      { from: 'html/elm-dice-serviceworker.js' },
      { from: 'html/cache-polyfill.js' },
      { from: 'html/sounds', to: 'sounds'},
      { from: 'html/assets', to: 'assets'},
    ]),
    new HtmlWebpackPlugin({
      template: 'html/index.html',
      inject: false,
    }),
  ].concat(env && logEnv(env.production)
    ? new webpack.optimize.UglifyJsPlugin({
        include: 'elm',
        compress: { 
          warnings: false,
          pure_funcs: [
              'F2',
              'F3',
              'F4',
              'F5',
              'F6',
              'F7',
              'F8',
              'F9',
              'A2',
              'A3',
              'A4',
              'A5',
              'A6',
              'A7',
              'A8',
              'A9'
          ],
          pure_getters: true,
          keep_fargs: false,
          unsafe_comps: true,
          unsafe: true
      }
    })
    : []),

  devServer: {
    host: '0.0.0.0',
    port: 5000,
    inline: true,
    stats: 'errors-only',
    contentBase: './html',
    historyApiFallback: true,
    disableHostCheck: true,
  }
});

