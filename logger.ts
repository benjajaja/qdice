import * as pino from "pino";

const logger = pino({
  level: "debug",
  timestamp: false,
  prettyPrint: true,
});
logger.pipe = <T>(message: string, arg: T) => {
  logger.info(message, arg);
  return arg;
};
export default logger;
