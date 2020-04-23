import * as fs from "fs";
import * as path from "path";
import * as R from "ramda";
import * as errs from "restify-errors";
import * as request from "request";
import * as restify from "restify";
import * as jwt from "jsonwebtoken";
import * as Scrypt from "scrypt-kdf";
import * as db from "./db";
import * as publish from "./table/publish"; // avoid or refactor
import logger from "./logger";
import { Preferences, PushNotificationEvents, User, UserId } from "./types";
import { Request } from "restify";
import * as dataUrlStream from "data-url-stream";
import { savePicture, downloadPicture } from "./helpers";
import { NETWORK_PASSWORD } from "./db";

const GOOGLE_OAUTH_SECRET = process.env.GOOGLE_OAUTH_SECRET;
const REDDIT_OAUTH_SECRET = process.env.REDDIT_OAUTH_SECRET;

export const defaultPreferences = (): Preferences => ({});

export const login = async (req, res, next) => {
  try {
    const network = req.params.network;
    if (network === "password") {
      try {
        if ((req.body.email ?? "") === "" || (req.body.password ?? "") === "") {
          return res.send(400, "missing parameters");
        }
        const id = await db.getUserId(req.body.email);
        const oldPassword = await db.getPassword(id);
        const buffer = Buffer.from(oldPassword, "base64");
        const ok = await Scrypt.verify(buffer, req.body.password);

        if (!ok) {
          return res.send(403, "bad password");
        }

        const profile = await db.getUser(id);
        const token = jwt.sign(
          JSON.stringify(profile),
          process.env.JWT_SECRET!
        );
        res.sendRaw(200, token);
        next();
      } catch (e) {
        logger.error(e);
        next(e);
      } finally {
        return;
      }
    }

    const profile = await getProfile(
      network,
      req.body,
      req.headers.origin + "/"
    );
    logger.debug("login", profile.id);

    let user = await db.getUserFromAuthorization(network, profile.id);
    if (!user) {
      user = await db.createUser(
        network,
        profile.id, // network-id, not user-id
        profile.name,
        profile.email,
        "",
        {} // GDPR friendly: don't save everything
      );

      // TODO move this into db.createUser somehow
      let picture: string | null = null;
      try {
        picture = await downloadPicture(user.id, profile.picture);
      } catch (e) {
        logger.error(e);
      }
      user = await db.updateUser(user.id, {
        name: null,
        email: null,
        picture,
        password: null,
      });
    }

    const token = jwt.sign(JSON.stringify(user), process.env.JWT_SECRET!);
    res.sendRaw(200, token);
    next();
  } catch (e) {
    logger.error(`login error: ${e.toString()}`);
    next(new errs.InternalError("could not log in"));
  }
};

export const addLogin = (req, res, next) => {
  const network = req.params.network;
  getProfile(network, req.body, req.headers.origin + "/")
    .then(profile => {
      logger.debug("addlogin", profile);
      return db
        .getUserFromAuthorization(network, profile.id)
        .then(user => {
          if (user) {
            throw new Error("already registered");
          }
          db.getUser(req.user.id);
          return db.addNetwork(
            req.user.id,
            network,
            profile.id,
            {} // GDPR friendly: don't save everything
          );
        })
        .then(user => {
          const token = jwt.sign(JSON.stringify(user), process.env.JWT_SECRET!);
          res.sendRaw(200, token);
          next();
        });
    })
    .catch(e => {
      console.error("login error", e.toString());
      res.send(
        403,
        "Already registered for another user. Logout and login again."
      );
      next();
    });
};

const getProfile = (network, code, referer): Promise<any> => {
  return new Promise((resolve, reject) => {
    const options = {
      [db.NETWORK_GOOGLE]: {
        url: "https://www.googleapis.com/oauth2/v4/token",
        form: {
          code: code,
          client_id:
            "1000163928607-54qf4s6gf7ukjoevlkfpdetepm59176n.apps.googleusercontent.com",
          client_secret: GOOGLE_OAUTH_SECRET,
          scope: ["email", "profile"],
          grant_type: "authorization_code",
          redirect_uri: referer,
        },
      },
      [db.NETWORK_REDDIT]: {
        url: "https://www.reddit.com/api/v1/access_token",
        form: {
          code: code,
          scope: ["identity"],
          grant_type: "authorization_code",
          redirect_uri: referer,
        },
        auth: {
          username: "Ik08wUaMvoUZ3A",
          password: REDDIT_OAUTH_SECRET,
        },
      },
    }[network];

    request(Object.assign({ method: "POST" }, options), function(
      err,
      response,
      body
    ) {
      if (err) {
        return reject(err);
      } else if (response.statusCode !== 200) {
        logger.error(
          "could not get access_token",
          code,
          referer,
          body.toString()
        );
        return reject(new Error(`token request status ${response.statusCode}`));
      }
      var json = JSON.parse(body);
      request(
        {
          url: {
            [db.NETWORK_GOOGLE]: "https://www.googleapis.com/userinfo/v2/me",
            [db.NETWORK_REDDIT]: "https://oauth.reddit.com/api/v1/me",
          }[network],
          method: "GET",
          headers: {
            "User-Agent": "webapp:qdice.wtf:v1.0",
            Authorization: json.token_type + " " + json.access_token,
          },
        },
        function(err, response, body) {
          if (err) {
            return reject(err);
          } else if (response.statusCode !== 200) {
            console.error(body);
            return reject(new Error(`profile ${response.statusCode}`));
          }
          const profile = JSON.parse(body);
          resolve(profile);
        }
      );
    });
  });
};

export const me = async function(req, res, next) {
  try {
    const profile = await db.getUser(req.user.id);
    const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET!);
    const preferences = await db.getPreferences(req.user.id);
    res.send(200, [profile, token, preferences]);
    next();
  } catch (e) {
    logger.error("/me", req.user);
    logger.error(e);
    next(
      new errs.BadRequestError("could not get profile, JWT, or preferences")
    );
  }
};

export const profile = async function(req, res, next) {
  try {
    let password: string | null = null;
    if (req.body.password) {
      if ((req.body.passwordCheck ?? "").length === 0) {
        return res.send(400, "missing current password");
      }
      const oldPassword = await db.getPassword(req.user.id);
      const buffer = Buffer.from(oldPassword, "base64");
      const ok = await Scrypt.verify(buffer, req.body.passwordCheck);

      if (!ok) {
        return res.send(403, "bad password");
      }
      password = await hashPassword(req.body.password);
      logger.debug("changing password", ok);
    }

    const picture = req.body.picture
      ? await saveAvatar(req.user.id, req.body.picture)
      : null;
    logger.debug("saved", picture);

    const profile = await db.updateUser(req.user.id, {
      name: req.body.name,
      email: req.body.email,
      password,
      picture,
    });
    const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET!);
    res.sendRaw(200, token);
    next();
  } catch (e) {
    logger.error(e);
    res.sendRaw(500, "Something went wrong.");
  }
};

export const password = async function(req, res, next) {
  if (!(await db.isAvailable(req.body.email))) {
    res.sendRaw(400, "Email already exists");
    return next();
  }
  logger.debug("email did not exist");
  try {
    const password = await hashPassword(req.body.password);
    const profile = await db.updateUser(req.user.id, {
      email: req.body.email,
      name: null,
      picture: null,
      password: password,
    });
    const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET!);
    res.sendRaw(200, token);
    next();
  } catch (e) {
    logger.error(e);
    next(e);
  }
};

const hashPassword = async function(password: string) {
  const buffer = await Scrypt.kdf(password, {
    logN: 15,
    r: 8,
    p: 1,
  });
  return buffer.toString("base64");
};

export const register = function(req: restify.Request, res, next) {
  const profile =
    req.header("Origin").indexOf(".ssl.hwcdn.net") !== -1
      ? { itchio: true }
      : null;
  logger.debug(profile);
  db.createUser(db.NETWORK_PASSWORD, null, req.body.name, null, null, profile)
    .then(profile => {
      const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET!);
      res.sendRaw(200, token);
      next();
    })
    .catch(e => next(e));
};

export const del = function(req, res, next) {
  db.deleteUser(req.user.id)
    .then(_ => {
      res.send(200);
      next();
    })
    .catch(e => next(e));
};

export const addPushSubscription = (add: boolean) => (req, res, next) => {
  const subscription = req.body;
  const user: User = (req as any).user;
  logger.debug("register push endpoint", subscription, user.id);
  db.addPushSubscription(user.id, subscription, add)
    .then(profile => {
      const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET!);
      res.sendRaw(200, token);
    })
    .catch(e => {
      console.error(e);
      return Promise.reject(e);
    })
    .catch(e => next(e));
};

export const addPushEvent = (add: boolean) => (req, res, next) => {
  const event = req.body;
  const user: User = (req as any).user;
  logger.debug("register push event", event, user.id);
  db.addPushEvent(user.id, event, add)
    .then(profile => {
      const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET!);
      res.sendRaw(200, token);
    })
    .catch(e => {
      console.error(e);
      return Promise.reject(e);
    })
    .catch(e => next(e));
};

export const registerVote = (source: "topwebgames") => async (
  req: Request,
  res,
  next
) => {
  try {
    const { ID, uid, votecounted, client_id } = req.query;
    logger.debug("register vote", source, ID, uid, votecounted, client_id);
    const user = await db.getUser(uid);
    if (user.voted.indexOf(source) !== -1) {
      return next(new Error(`user ${user.id} already voted "${source}"`));
    }
    await db.registerVote(user, source);
    const profile = await db.addScore(user.id, 1000);
    if (client_id) {
      const preferences = await db.getPreferences(profile.id);
      publish.userUpdate(client_id)(profile, preferences);
      publish.userMessage(client_id, "You received 1000✪!");
    }
    logger.debug("voted", profile, user);
    res.sendRaw(200, "ok");
  } catch (e) {
    console.error(e);
    next(e);
  }
};

const saveAvatar = (id: UserId, url: string): Promise<string> => {
  logger.debug("picture:", url.slice(0, 20));
  const filename = `user_${id}.gif`;
  const stream: fs.ReadStream = dataUrlStream(url);
  return savePicture(filename, stream);
};
