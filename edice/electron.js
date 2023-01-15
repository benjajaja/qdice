const { app, BrowserWindow, protocol, ipcMain, MessageChannelMain } = require("electron");
const path = require("path");
const fs = require("fs");
const fetch = require("electron-fetch").default;
const mime = require("mime-type/with-db");
const steamworks = require('steamworks.js');

function createWindow() {
  // Create the browser window.
  let win = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      webSecurity: false,
      contextIsolation: true,
      nodeIntegration: false,
      preload: path.join(__dirname, 'preload.js'),
    },
    // titleBarStyle: 'hidden',
    autoHideMenuBar: true,
    icon: 'favicons-2/favicon.png',
  });

  ipcMain.handle('steamworks:steamId', async (event) => {
    // We'll be sending one end of this channel to the main world of the
    // context-isolated page.
    const { port1, port2 } = new MessageChannelMain()

    // It's OK to send a message on the channel before the other end has
    // registered a listener. Messages will be queued until a listener is
    // registered.
    // port2.postMessage({ test: 21 })

    // We can also receive messages from the main world of the renderer.
    port2.on('message', (event) => {
      console.log('from renderer main world:', event.data)
    })
    port2.start()
    win.webContents.postMessage('main-world-port', null, [port1]);

    // The preload script will receive this IPC message and transfer the port
    // over to the main world.

    console.log("get steamid");
    console.time("steam");
    try {
      const client = steamworks.init(2255020);

      const ticket = await client.auth.getSessionTicket();

      console.log(client.localplayer.getName(), client.localplayer.getSteamId().steamId64);
      console.timeEnd("steam");
      const playerName = client.localplayer.getName();
      const steamId = client.localplayer.getSteamId();
      if (steamId === undefined) {
        throw new Error("could not get steamid");
      }
      console.log("postMessage", { steamId: steamId.steamId64, playerName, ticket: ticket.getBytes().toString('hex'), })
      port2.postMessage(JSON.stringify({ steamId: steamId.steamId64, playerName, ticket: ticket.getBytes().toString('hex'), }));
    } catch (e) {
      console.error("Steam communication error", e);
      port2.postMessage(JSON.stringify({ error: e.toString() }));
    }
  })

  // and load the index.html of the app.
  // win.webContents.openDevTools();
  // win.loadURL("http://localhost:5000");
  intercept();
  win.loadURL("http://electron/Planeta");

}

let indexLoaded = false;
function intercept() {
  protocol.interceptBufferProtocol("http", function(req, callback) {
    let split = req.url.split("http://electron/")[1];
    if (split === undefined) {
      console.log("unhandled url", req.url);
      fetch(req.url).then(res => res.buffer()).then(callback);
      return
    }

    const isFetch = ///.*\.svg$/.test(req.url) === true ||
      split.indexOf("pictures/") === 0;

    if (isFetch) {
      const url = "https://qdice.wtf/" + split;
      fetch(url).then(res => res.buffer()).then(buffer => {
        callback(buffer)
      }).catch(err => {
        console.error("fetch error", url, err.toString());
        callback({
          error: -2,
          statusCode: 404,
        });
      });
    } else {
      try {
        if (!indexLoaded && split === "Planeta") {
          indexLoaded = true;
          split = "index.html";
        }
        // const filePath = path.join(".", "resources", "app", split);
        const filePath = path.join(".", "dist", split);
        fs.readFile(filePath, (err, data) => {
          if (err) {
            console.error(err.toString());
            callback({
              error: -2,
              statusCode: 404,
            });
          } else {
            callback({
              data,
              mimeType: mimeType(req),
            });
          }
        });
      } catch (e) {
        console.error("non-fetch error", e.toString());
      }
    }
  });
}

function mimeType(req) {
  const m = mime.lookup(req.url);
  if (m === false) {
    console.log("unknown mime type:", req.url);
    return req.headers["Accept"].split(",")[0];
  }
  return m;
}

app.on("ready", createWindow);

steamworks.electronEnableSteamOverlay();
