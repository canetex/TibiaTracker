import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import CssBaseline from '@mui/material/CssBaseline';

import App from './App';
import { ThemeProvider } from './contexts/ThemeContext';
import reportWebVitals from './reportWebVitals';

// Importar fontes
import '@fontsource/montserrat/300.css';
import '@fontsource/montserrat/400.css';
import '@fontsource/montserrat/500.css';
import '@fontsource/montserrat/600.css';
import '@fontsource/montserrat/700.css';

const root = ReactDOM.createRoot(document.getElementById('root'));

root.render(
  <React.StrictMode>
    <BrowserRouter>
      <ThemeProvider>
        <CssBaseline />
        <App />
      </ThemeProvider>
    </BrowserRouter>
  </React.StrictMode>
);

// Se você quiser começar a medir performance na sua app, passe uma função
// para registrar os resultados (por exemplo: reportWebVitals(console.log))
// ou envie para um endpoint de analytics. Saiba mais: https://bit.ly/CRA-vitals
reportWebVitals(); 