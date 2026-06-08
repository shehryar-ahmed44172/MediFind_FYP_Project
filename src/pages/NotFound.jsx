import React, { useEffect, useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { Home, ArrowLeft, AlertTriangle, Activity } from 'lucide-react';
import logo from '../assets/Medifind_New_Logo-removebg-preview.png';

export default function NotFound() {
  const navigate = useNavigate();
  const location = useLocation();
  const [countdown, setCountdown] = useState(10);

  // Auto-redirect countdown
  useEffect(() => {
    const timer = setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) {
          clearInterval(timer);
          navigate('/', { replace: true });
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [navigate]);

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #03293C 0%, #0C637E 55%, #2496A7 100%)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: "'Inter', 'Segoe UI', system-ui, sans-serif",
      padding: '2rem',
      position: 'relative',
      overflow: 'hidden',
    }}>

      {/* Background pulse rings */}
      {[1, 2, 3].map(i => (
        <div key={i} style={{
          position: 'absolute',
          width: `${i * 220}px`,
          height: `${i * 220}px`,
          borderRadius: '50%',
          border: '1px solid rgba(255,255,255,0.06)',
          top: '50%', left: '50%',
          transform: 'translate(-50%, -50%)',
          animation: `pulse ${2 + i * 0.5}s ease-in-out infinite`,
          pointerEvents: 'none',
        }} />
      ))}

      {/* Floating ECG line decoration */}
      <div style={{
        position: 'absolute', top: '12%', left: 0, right: 0,
        height: '2px', overflow: 'visible', opacity: 0.12, pointerEvents: 'none',
      }}>
        <svg width="100%" height="60" viewBox="0 0 1200 60" preserveAspectRatio="none">
          <polyline
            points="0,30 200,30 240,10 260,50 280,5 300,55 320,30 500,30 540,10 560,50 580,5 600,55 620,30 800,30 840,10 860,50 880,5 900,55 920,30 1200,30"
            fill="none" stroke="white" strokeWidth="2"
          />
        </svg>
      </div>

      {/* Card */}
      <div style={{
        background: 'rgba(255,255,255,0.07)',
        backdropFilter: 'blur(20px)',
        WebkitBackdropFilter: 'blur(20px)',
        border: '1px solid rgba(255,255,255,0.15)',
        borderRadius: '28px',
        padding: '3rem 3.5rem',
        maxWidth: '560px',
        width: '100%',
        textAlign: 'center',
        boxShadow: '0 32px 80px rgba(0,0,0,0.4)',
        position: 'relative',
        zIndex: 1,
      }}>

        {/* Logo */}
        <div style={{ marginBottom: '2rem' }}>
          <img
            src={logo}
            alt="MediFind"
            style={{
              height: '52px',
              objectFit: 'contain',
              filter: 'brightness(1.3) drop-shadow(0 2px 8px rgba(0,0,0,0.3))',
            }}
          />
        </div>

        {/* 404 Badge */}
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: '0.5rem',
          background: 'rgba(239,68,68,0.18)',
          border: '1px solid rgba(239,68,68,0.4)',
          borderRadius: '999px',
          padding: '0.35rem 1rem',
          marginBottom: '1.5rem',
        }}>
          <AlertTriangle size={14} color="#FCA5A5" />
          <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#FCA5A5', letterSpacing: '0.08em', textTransform: 'uppercase' }}>
            Error 404 — Page Not Found
          </span>
        </div>

        {/* Big 404 number */}
        <div style={{
          fontSize: '7rem',
          fontWeight: 900,
          lineHeight: 1,
          marginBottom: '1rem',
          background: 'linear-gradient(135deg, #ffffff 0%, #7DD3FC 60%, #38BDF8 100%)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
          backgroundClip: 'text',
          letterSpacing: '-4px',
        }}>
          404
        </div>

        {/* Heading */}
        <h1 style={{
          fontSize: '1.5rem',
          fontWeight: 800,
          color: 'white',
          marginBottom: '0.75rem',
          letterSpacing: '-0.02em',
        }}>
          This page doesn't exist
        </h1>

        {/* Sub message */}
        <p style={{
          fontSize: '0.95rem',
          color: 'rgba(255,255,255,0.65)',
          lineHeight: 1.7,
          marginBottom: '0.5rem',
        }}>
          The URL <code style={{
            background: 'rgba(255,255,255,0.1)',
            padding: '2px 8px',
            borderRadius: '6px',
            fontSize: '0.85rem',
            color: '#7DD3FC',
            fontFamily: 'monospace',
          }}>{location.pathname}</code> could not be found.
        </p>
        <p style={{
          fontSize: '0.85rem',
          color: 'rgba(255,255,255,0.45)',
          marginBottom: '2.5rem',
          lineHeight: 1.6,
        }}>
          It may have been moved, deleted, or you may have typed the address incorrectly.
        </p>

        {/* Buttons */}
        <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center', flexWrap: 'wrap', marginBottom: '2rem' }}>
          <button
            onClick={() => navigate(-1)}
            style={{
              display: 'flex', alignItems: 'center', gap: '0.5rem',
              padding: '0.75rem 1.5rem', borderRadius: '12px',
              background: 'rgba(255,255,255,0.1)',
              border: '1px solid rgba(255,255,255,0.2)',
              color: 'white', fontWeight: 600, fontSize: '0.875rem',
              cursor: 'pointer', transition: 'all 0.2s',
              fontFamily: 'inherit',
            }}
            onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.18)'}
            onMouseLeave={e => e.currentTarget.style.background = 'rgba(255,255,255,0.1)'}
          >
            <ArrowLeft size={16} /> Go Back
          </button>

          <button
            onClick={() => navigate('/', { replace: true })}
            style={{
              display: 'flex', alignItems: 'center', gap: '0.5rem',
              padding: '0.75rem 1.5rem', borderRadius: '12px',
              background: 'linear-gradient(135deg, #0C637E, #2891C2)',
              border: 'none',
              color: 'white', fontWeight: 700, fontSize: '0.875rem',
              cursor: 'pointer', transition: 'all 0.2s',
              boxShadow: '0 4px 16px rgba(12,99,126,0.4)',
              fontFamily: 'inherit',
            }}
            onMouseEnter={e => e.currentTarget.style.opacity = '0.88'}
            onMouseLeave={e => e.currentTarget.style.opacity = '1'}
          >
            <Home size={16} /> Back to Home
          </button>

          <button
            onClick={() => navigate('/admin', { replace: true })}
            style={{
              display: 'flex', alignItems: 'center', gap: '0.5rem',
              padding: '0.75rem 1.5rem', borderRadius: '12px',
              background: 'rgba(36,150,167,0.2)',
              border: '1px solid rgba(36,150,167,0.4)',
              color: '#7DD3FC', fontWeight: 600, fontSize: '0.875rem',
              cursor: 'pointer', transition: 'all 0.2s',
              fontFamily: 'inherit',
            }}
            onMouseEnter={e => e.currentTarget.style.background = 'rgba(36,150,167,0.35)'}
            onMouseLeave={e => e.currentTarget.style.background = 'rgba(36,150,167,0.2)'}
          >
            <Activity size={16} /> Admin Dashboard
          </button>
        </div>

        {/* Auto-redirect countdown */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.75rem',
        }}>
          {/* Circular progress */}
          <svg width="28" height="28" viewBox="0 0 28 28" style={{ transform: 'rotate(-90deg)', flexShrink: 0 }}>
            <circle cx="14" cy="14" r="11" fill="none" stroke="rgba(255,255,255,0.1)" strokeWidth="2.5" />
            <circle
              cx="14" cy="14" r="11" fill="none"
              stroke="#2891C2" strokeWidth="2.5"
              strokeDasharray={`${2 * Math.PI * 11}`}
              strokeDashoffset={`${2 * Math.PI * 11 * (1 - countdown / 10)}`}
              strokeLinecap="round"
              style={{ transition: 'stroke-dashoffset 0.9s linear' }}
            />
          </svg>
          <span style={{ fontSize: '0.8rem', color: 'rgba(255,255,255,0.45)' }}>
            Redirecting to home in <strong style={{ color: 'rgba(255,255,255,0.75)' }}>{countdown}s</strong>
          </span>
        </div>
      </div>

      {/* Footer */}
      <p style={{
        marginTop: '2rem',
        fontSize: '0.75rem',
        color: 'rgba(255,255,255,0.3)',
        letterSpacing: '0.04em',
        position: 'relative', zIndex: 1,
      }}>
        MediFind Emergency Response Network · Pakistan
      </p>

      {/* CSS animations */}
      <style>{`
        @keyframes pulse {
          0%, 100% { transform: translate(-50%, -50%) scale(1); opacity: 0.6; }
          50% { transform: translate(-50%, -50%) scale(1.06); opacity: 1; }
        }
      `}</style>
    </div>
  );
}
