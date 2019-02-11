import * as R from 'ramda';
import * as request from 'request';
import * as jwt from 'jsonwebtoken';
import * as db from './db';

const GOOGLE_OAUTH_SECRET = process.env.GOOGLE_OAUTH_SECRET;

export const login = (req, res, next) => {
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

      console.log('login', profile);
      db.getUserFromAuthorization(db.NETWORK_GOOGLE, profile.id)
      .then(user => {
        console.log('got user', user);
        if (user) {
          return user;
        }
        console.log('create');
        return db.createUser(db.NETWORK_GOOGLE, profile.id, profile.name, profile.email, profile.picture, profile);
      })
      .then(profile => {
        console.log('got profile', profile);
        const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET);
        res.send(200, token);
        next();
      }).catch(e => {
        console.error('/login error', e.toString());
        next(e);
      });
    });
  });
};

export const me = function(req, res, next) {
  db.getUser(req.user.id)
  .then(profile => {
    const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET);
    res.send(200, [profile, token]);
    next();
  })
  .catch(e => next(e));
};

export const profile = function(req, res, next) {
  db.updateUser(req.user.id, req.body.name, req.body.email)
  .then(profile => {
    const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET);
    res.send(200, token);
    next();
  })
  .catch(e => {
    console.error(e);
    return Promise.reject(e);
  })
  .catch(e => next(e));
};

export const register = function(req, res, next) {
  db.createUser(db.NETWORK_PASSWORD, null, req.body.name, null, null, null)
  .then(profile => {
    const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET);
    res.send(200, token);
    next();
  })
  .catch(e => next(e));
};

