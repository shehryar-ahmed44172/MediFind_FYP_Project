import React from 'react';
import { TileLayer } from 'react-leaflet';
import { useTheme } from '../context/hooks';
import './themedTiles.css';

/*
 * OpenStreetMap tiles that follow the admin theme. In dark mode the tiles are
 * colour-inverted with a CSS filter (no extra tile service or API key needed),
 * so the map doesn't glare on a dark page; markers keep their real colours.
 */
export default function ThemedTileLayer() {
  const { theme } = useTheme();
  return (
    <TileLayer
      key={theme}
      url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      className={theme === 'dark' ? 'mf-tiles-dark' : undefined}
    />
  );
}
