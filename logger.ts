const logger = {
  log: console.log.bind(console),
  debug: console.debug.bind(console),
  warn: console.warn.bind(console),
  error: console.error.bind(console),
  info: console.info.bind(console),
  pipe: <T>(message: string, arg: T) => {
    console.log(message, arg);
    return arg;
  },
};
export default logger;
