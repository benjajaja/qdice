import logger from "./logger";
import * as publish from "./table/publish";
import * as mqtt from "mqtt";

export const toast = async (args: string[]) => {
  const message = args.slice(2).join(" ");
  logger.debug(`global toast: ${message}`);

  var client = mqtt.connect(process.env.MQTT_URL, {
    clientId: "nodice",
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
  });

  client.on("connect", () => {
    logger.info("connected to mqtt.");
    publish.setMqtt(client);
    publish.toast(message);
    client.end();
  });
  // const allClients = await db.allTableClients();
  // logger.debug(`to ${JSON.stringify(allClients)}`);
  // await db.disconnect();
};
