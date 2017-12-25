const request = require('request');
const jwt = require('jsonwebtoken');
const ShortUniqueId = require('short-unique-id');

const GOOGLE_OAUTH_SECRET = process.env.GOOGLE_OAUTH_SECRET;
if (!GOOGLE_OAUTH_SECRET) throw new Error('GOOGLE_OAUTH_SECRET env var not found');

exports.login = function(req, res, next) {
  request({
    url: 'https://www.googleapis.com/oauth2/v4/token',
    method: 'POST',
    //headers: {
      //authorization: req.body,
    //},
    form: {
      code: req.body,
      client_id: '1000163928607-54qf4s6gf7ukjoevlkfpdetepm59176n.apps.googleusercontent.com',
      client_secret: GOOGLE_OAUTH_SECRET,
      scope: ['email', 'profile'],
      grant_type: 'authorization_code',
      redirect_uri: req.headers.referer,
    }
  }, function(err, response, body) {
    var json = JSON.parse(body);
    request({
      url: 'https://www.googleapis.com/userinfo/v2/me',
      method: 'GET',
      headers: {
        authorization: json.token_type + ' ' + json.access_token,
      },
    }, function(err, response, body) {
      const profile = JSON.parse(body);
      const user = {
        id: 'google_' + profile.id,
        name: profile.name,
        email: profile.email,
        picture: profile.picture,
      };
      const token = jwt.sign(user, process.env.JWT_SECRET);
      res.send(200, token); //Object.assign({ token }, user));
      next();
    });
  });
};

exports.me = function(req, res, next) {
  res.send(200, req.user);
  next();
};

exports.profile = function(req, res, next) {
  const profile = Object.assign({}, req.user, { name: req.body.name });
  const token = jwt.sign(profile, process.env.JWT_SECRET);
  res.send(200, token);
  next();
};

const uid = new ShortUniqueId();
exports.register = function(req, res, next) {
  const profile = {
    name: req.body.name,
    id: `quedice_${uid.randomUUID(16)}`,
    email: '',
    picture: 'assets/empty_profile_picture.svg',
  };
  const token = jwt.sign(profile, process.env.JWT_SECRET);
  res.send(200, token);
  next();
};

