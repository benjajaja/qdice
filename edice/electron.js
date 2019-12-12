const { app, BrowserWindow, protocol } = require("electron");
const path = require("path");
const fs = require("fs");
const fetch = require("electron-fetch").default;
const mime = require("mime-type/with-db");

function createWindow() {
  // Create the browser window.
  let win = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      nodeIntegration: false,
      webSecurity: false,
    },
  });

  // and load the index.html of the app.
  win.loadURL("http://electron/index.html");
}

function createElmWindow() {
  protocol.interceptBufferProtocol("http", function(req, callback) {
    const split = req.url.split("http://electron/")[1];
    if (split.indexOf("ackee/") === 0 || /.*\.svg$/.test(req.url) === true) {
      const resource = {
        url: "https://qdice.wtf/" + split,
        method: req.method,
      };
      console.log("fetch", resource);
      fetch(resource).then(res => {
        res.text().then(text => {
          callback({
            mimeType: req.headers["Accept"].split(",")[0],
            text,
          });
        });
      });
    } else {
      const filePath = path.join(".", "dist", split);
      const data = fs.readFileSync(filePath);

      console.log("intercept file", filePath, data.length);
      callback(data);
      // callback({
      // charset: "utf8",
      // mimeType: mimeType(req),
      // data,
      // });
    }
  });
  createWindow();
}

function mimeType(req) {
  const m = mime.lookup(req.url);
  if (m === false) {
    console.log("unknown mime type:", req.url);
    return req.headers["Accept"].split(",")[0];
  }
  return m;
}

app.on("ready", createElmWindow);
