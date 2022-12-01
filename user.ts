import * as fs from "fs";
import * as R from "ramda";
import * as errs from "restify-errors";
import * as request from "request";
import * as rp from "request-promise-native";
import * as restify from "restify";
import * as jwt from "jsonwebtoken";
import * as Scrypt from "scrypt-kdf";
import * as db from "./db";
import * as publish from "./table/publish"; // avoid or refactor
import logger from "./logger";
import { Preferences, User, UserId, Network } from "./types";
import { Request } from "restify";
import * as dataUrlStream from "data-url-stream";
import { savePicture, downloadPicture, CropData } from "./helpers";

const GOOGLE_OAUTH_SECRET = process.env.GOOGLE_OAUTH_SECRET;
const GITHUB_OAUTH_SECRET = process.env.GITHUB_OAUTH_SECRET;
const REDDIT_OAUTH_SECRET = process.env.REDDIT_OAUTH_SECRET;

const STEAM_WEB_API_KEY = process.env.STEAM_WEB_API_KEY;
const STEAM_APPID = process.env.STEAM_APPID;

export const defaultPreferences = (): Preferences => ({});

export const login = async (req, res, next) => {
  try {
    const network: Network | undefined = req.params.network;
    if (!network) {
      return next(new errs.InternalError("unknown network"));
    }
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
          return res.send(403, "bad user/password");
        }

        const profile = await db.getUser(id);
        const token = jwt.sign(
          JSON.stringify(profile),
          process.env.JWT_SECRET!
        );
        res.sendRaw(200, token);
        next();
      } catch (e) {
        return res.send(403, "bad user/password");
      } finally {
        return;
      }
    }

    if (network === "steam") {
      return steamAuth(
        req.body.steamId,
        req.body.playerName,
        req.body.ticket,
        res,
        next
      );
    }

    const profile = await getProfile(
      network,
      req.body,
      req.headers.origin + "/"
    );
    logger.debug("login", profile.id);

    let user = await db.getUserFromAuthorization(network, profile.id);
    if (!user) {
      let name = profile.name;
      if (network === db.NETWORK_GITHUB && profile.login) {
        name = profile.login;
      } else if (network === db.NETWORK_STEAM && profile.personaname) {
        name = profile.personaname;
      }
      logger.debug("profile", profile);
      user = await db.createUser(
        network,
        profile.id, // network-id, not user-id
        name,
        profile.email,
        "",
        profile
      );

      // TODO move this into db.createUser somehow
      let picture: string | null = null;
      const pictureURL = profile.picture ?? profile.avatar_url ?? null;
      if (pictureURL) {
        try {
          picture = await downloadPicture(user.id, pictureURL);
        } catch (e) {
          logger.error(e);
        }
      }
      if (picture) {
        user = await db.updateUser(user.id, {
          name: null,
          email: null,
          picture,
          password: null,
        });
      }
    }

    const token = jwt.sign(JSON.stringify(user), process.env.JWT_SECRET!);
    res.sendRaw(200, token);
    next();
  } catch (e) {
    logger.error(`login error: ${e.toString()}`, e);
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
          // db.getUser(req.user.id);
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

const getProfile = (
  network: Network,
  code: string,
  referer: string
): Promise<any> => {
  if (network === db.NETWORK_STEAM) {
    return getSteamProfile(code);
  }
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
      [db.NETWORK_GITHUB]: {
        url: "https://github.com/login/oauth/access_token",
        form: {
          code: code,
          client_id: "acbcad9ce3615b6fb44d",
          client_secret: GITHUB_OAUTH_SECRET,
          redirect_uri: referer,
        },
        headers: {
          Accept: "application/json",
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
          username: "FjcCKkabynWNug",
          password: REDDIT_OAUTH_SECRET,
        },
      },
    }[network];

    const req = { method: "POST", ...options };
    request(req, function(err, response, body) {
      if (err) {
        logger.debug(
          "login token request error",
          network,
          R.omit(["client_secret", "auth"], options)
        );
        return reject(err);
      } else if (response.statusCode !== 200) {
        logger.error(
          "could not get access_token",
          code,
          referer,
          body.toString(),
          req
        );
        return reject(new Error(`token request status ${response.statusCode}`));
      }
      var json = JSON.parse(body);
      request(
        {
          url: {
            [db.NETWORK_GOOGLE]: "https://www.googleapis.com/userinfo/v2/me",
            [db.NETWORK_REDDIT]: "https://oauth.reddit.com/api/v1/me",
            [db.NETWORK_GITHUB]: "https://api.github.com/user",
          }[network],
          method: "GET",
          headers: {
            "User-Agent": "webapp:qdice.wtf:v1.0",
            Authorization: json.token_type + " " + json.access_token,
            Accept: "application/json",
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

export const me = async function(
  req: restify.Request & { user: { id: string } },
  res,
  next
) {
  try {
    const profile = await db.getUser(req.user.id, req.header("X-Real-IP"));
    const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET!);
    const preferences = await db.getPreferences(req.user.id);
    res.send(200, [R.omit(["ip"], profile), token, preferences]);
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
    if (e.message === "user update needs some fields") {
      res.sendRaw(400, "Profile was not updated because nothing has changed.");
    } else {
      res.sendRaw(500, "Something went wrong.");
    }
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

export const addPushSubscription = (add: boolean) => async (req, res, next) => {
  const subscription = req.body;
  const user: User = (req as any).user;
  try {
    await db.addPushSubscription(user.id, subscription, add);
    const profile = await db.addPushEvent(user.id, "turn", add);
    const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET!);
    const preferences = await db.getPreferences(user.id);
    res.send(200, [R.omit(["ip"], profile), token, preferences]);
  } catch (e) {
    console.error(e);
    next(e);
  }
};

export const addPushEvent = (add: boolean) => async (req, res, next) => {
  const event = req.body;
  const user: User = (req as any).user;
  logger.debug("register push event", event, user.id);
  db.addPushEvent(user.id, event, add)
    .then(async profile => {
      const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET!);
      const preferences = await db.getPreferences(user.id);
      res.send(200, [R.omit(["ip"], profile), token, preferences]);
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

const saveAvatar = (
  id: UserId,
  crop: CropData & { url: string }
): Promise<string> => {
  const suffix = `${Math.floor(Math.random() * 10000)}`;
  const filename = `user_${id}_${suffix}.png`;
  const stream: fs.ReadStream = dataUrlStream(crop.url);
  return savePicture(filename, stream, R.omit(["url"], crop));
};

const steamAuth = async (
  steamId: string,
  playerName: string,
  ticket: string,
  res,
  next
) => {
  if (!steamId || !ticket) {
    return res.send(400, "Missing steamId/ticket");
  }

  try {
    const body = await rp({
      method: "GET",
      url:
        "https://api.steampowered.com/ISteamUserAuth/AuthenticateUserTicket/v1/",
      qs: {
        key: STEAM_WEB_API_KEY,
        appid: STEAM_APPID,
        ticket: ticket,
      },
    });
    console.log("rp:", body);
    const params = JSON.parse(body).response.params;
    if (params.result !== "OK") {
      return res.send(500, 'steam response not "OK"');
    }
    if (params.steamid !== steamId) {
      return res.send(500, "mismatching steamids");
    }

    let user = await db.getUserFromAuthorization(db.NETWORK_STEAM, steamId);
    if (!user) {
      const profile = await getSteamProfile(steamId);
      user = await db.createUser(
        db.NETWORK_STEAM,
        steamId, // network-id, not user-id
        profile.personaname,
        null,
        "",
        profile
      );

      // TODO move this into db.createUser somehow
      let picture: string | null = null;
      const pictureURL = profile.avatarfull ?? null;
      if (pictureURL) {
        try {
          picture = await downloadPicture(user.id, pictureURL);
        } catch (e) {
          logger.error(e);
        }
      }
      if (picture) {
        user = await db.updateUser(user.id, {
          name: null,
          email: null,
          picture,
          password: null,
        });
      }
    }

    const token = jwt.sign(JSON.stringify(user), process.env.JWT_SECRET!);
    res.sendRaw(200, token);
    next();
  } catch (e) {
    return res.send(500, "error: " + e);
  }
};

const getSteamProfile = async (
  steamId: string
): Promise<{
  personaname: string;
  avatarfull: string;
  steamid: string;
}> => {
  const body = await rp({
    method: "GET",
    url: "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/",
    qs: {
      key: STEAM_WEB_API_KEY,
      steamids: steamId,
    },
  });
  const profile = JSON.parse(body).response.players[0];
  if (profile.steamid !== steamId) {
    throw new Error("mismatching steamids (profile)");
  }
  profile.id = profile.steamid;
  return profile;
};
