import React, { useEffect, useState } from 'react';
import { ThemeContext } from './contexts';

export const ThemeProvider = ({ children }) => {
  const [theme, setTheme] = useState(() => {
    // Respect explicitly saved preference; always default to light
    const saved = localStorage.getItem('medifind-theme');
    return saved === 'dark' ? 'dark' : 'light';
  });

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('medifind-theme', theme);
  }, [theme]);

  const toggleTheme = () => setTheme(prev => (prev === 'light' ? 'dark' : 'light'));

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  );
};
