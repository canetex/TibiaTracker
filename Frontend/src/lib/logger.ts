type LogLevel = 'debug' | 'info' | 'warn' | 'error';

// Desabilitar completamente logs de debug
const LOG_LEVEL: LogLevel = 'error';

const logger = {
  debug: (...args: any[]) => {
    // Desabilitado completamente
  },
  info: (...args: any[]) => {
    // Desabilitado completamente
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