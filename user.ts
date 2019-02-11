import * as R from 'ramda';
import * as request from 'request';
import * as jwt from 'jsonwebtoken';
import * as db from './db';

const GOOGLE_OAUTH_SECRET = process.env.GOOGLE_OAUTH_SECRET;

export const login = (req, res, next) => {
  const network = req.params.network;
  getProfile(network, req.body, req.headers.referer)
  .then(profile => {
    console.log('login', profile);
    return db.getUserFromAuthorization(network, profile.id)
    .then(user => {
      console.log('got user', user);
      if (user) {
        return user;
      }
      console.log('create');
      return db.createUser(network, profile.id, profile.name, profile.email, profile.picture, profile);
    })
    .then(profile => {
      console.log('got profile', profile);
      const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET);
      res.send(200, token);
      next();
    });
  }).catch(e => {
    console.error('login error', e.toString());
    next(e);
  });
};

const getProfile = (network, code, referer): Promise<any> => {
  return new Promise((resolve, reject) => {
    const options = {
      [db.NETWORK_GOOGLE]: {
          url: 'https://www.googleapis.com/oauth2/v4/token',
          form: {
            code: code,
            client_id: '1000163928607-54qf4s6gf7ukjoevlkfpdetepm59176n.apps.googleusercontent.com',
            client_secret: GOOGLE_OAUTH_SECRET,
            scope: ['email', 'profile'],
            grant_type: 'authorization_code',
            redirect_uri: referer,
          }
        },
      [db.NETWORK_REDDIT]: {
          url: 'https://www.reddit.com/api/v1/access_token',
          form: {
            code: code,
            scope: ['identity'],
            grant_type: 'authorization_code',
            redirect_uri: referer,
          },
          auth: {
            username: 'FjcCKkabynWNug',
            password: 'TaKLR_955KZuWSF0GwkvZ2Wmeic',
          }
        }
    }[network];
    request(Object.assign({ method: 'POST' }, options), function(err, response, body) {
      if (err) {
        return reject(err);
      } else if (response.statusCode !== 200) {
        return reject(new Error(`token ${response.statusCode}`));
      }
      var json = JSON.parse(body);
      request({
        url: {
          [db.NETWORK_GOOGLE]: 'https://www.googleapis.com/userinfo/v2/me',
          [db.NETWORK_REDDIT]: 'https://oauth.reddit.com/api/v1/me',
        }[network],
        method: 'GET',
        headers: {
          'User-Agent': 'webapp:qdice.wtf:v1.0',
          Authorization: json.token_type + ' ' + json.access_token,
        },
      }, function(err, response, body) {
        if (err) {
          return reject(err);
        } else if (response.statusCode !== 200) {
          console.error(body);
          return reject(new Error(`profile ${response.statusCode}`));
        }
        const profile = JSON.parse(body);
        resolve(profile);
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

