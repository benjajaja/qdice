import * as pino from 'pino';

const logger = pino({ });
logger.pipe = <T>(message: string, arg: T) => {
  logger.info(message, arg);
  return arg;
};
export default logger;

