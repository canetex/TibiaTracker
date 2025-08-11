type LogLevel = 'debug' | 'info' | 'warn' | 'error';

const LOG_LEVEL: LogLevel = import.meta.env.MODE === 'development' ? 'debug' : 'error';

const logger = {
  debug: (...args: any[]) => {
    if (LOG_LEVEL === 'debug') {
      console.debug('[DEBUG]', ...args);
    }
  },
  info: (...args: any[]) => {
    if (['debug', 'info'].includes(LOG_LEVEL)) {
      console.info('[INFO]', ...args);
    }
  },
  warn: (...args: any[]) => {
    if (['debug', 'info', 'warn'].includes(LOG_LEVEL)) {
      console.warn('[WARN]', ...args);
    }
  },
  error: (...args: any[]) => {
    if (['debug', 'info', 'warn', 'error'].includes(LOG_LEVEL)) {
      console.error('[ERROR]', ...args);
    }
  }
};

export default logger; 