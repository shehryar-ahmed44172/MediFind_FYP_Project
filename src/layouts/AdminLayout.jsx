import React from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import {
  LayoutDashboard,
  Activity,
  UserCheck,
  History,
  Users,
  ShieldAlert,
  LogOut,
  Bell,
  CreditCard,
  Sun,
  Moon,
} from 'lucide-react';

const AdminLayout = () => {
  const { logout } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/login', { replace: true });
  };

  const isDark = theme === 'dark';

  return (
    <div className="admin-layout">
      <aside className="sidebar admin-sidebar">
        {/* ── Brand ─── */}
        <div className="sidebar-header">
          <div className="sidebar-logo">
            <ShieldAlert size={22} color="#ef4444" />
          </div>
          <div className="sidebar-brand">
            <span className="brand-name">MediFind</span>
            <span className="brand-sub">Admin Console</span>
          </div>
        </div>

        {/* ── Navigation ─── */}
        <nav className="sidebar-nav">
          <p className="nav-section-label">Main</p>
          <NavLink to="/admin" end className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}>
            <LayoutDashboard size={18} />
            <span>Overview</span>
          </NavLink>
          <NavLink to="/admin/sos" className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}>
            <Activity size={18} />
            <span>SOS Monitor</span>
          </NavLink>

          <p className="nav-section-label">Management</p>
          <NavLink to="/admin/verification" className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}>
            <UserCheck size={18} />
            <span>Verification</span>
          </NavLink>
          <NavLink to="/admin/users" className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}>
            <Users size={18} />
            <span>User Management</span>
          </NavLink>
          <NavLink to="/admin/subscriptions" className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}>
            <CreditCard size={18} />
            <span>Subscriptions</span>
          </NavLink>

          <p className="nav-section-label">System</p>
          <NavLink to="/admin/notifications" className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}>
            <Bell size={18} />
            <span>Notifications</span>
          </NavLink>
          <NavLink to="/admin/audit" className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}>
            <History size={18} />
            <span>Audit Logs</span>
          </NavLink>
        </nav>

        {/* ── Footer ─── */}
        <div className="sidebar-footer">
          <div className="sidebar-version">v2.0 · Emergency System</div>
          <button className="logout-btn" onClick={handleLogout}>
            <LogOut size={18} />
            <span>Sign Out</span>
          </button>
        </div>
      </aside>

      <main className="admin-main">
        {/* ── Header ─── */}
        <header className="admin-header">
          <div className="header-left">
            <div className="header-search">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" style={{ color: 'var(--text-muted)', flexShrink: 0 }}>
                <circle cx="11" cy="11" r="8" /><path d="m21 21-4.35-4.35" />
              </svg>
              <input type="text" placeholder="Search users, emergencies..." />
            </div>
          </div>

          <div className="header-actions">
            {/* Theme Toggle */}
            <button
              className="icon-btn theme-toggle"
              onClick={toggleTheme}
              title={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
              aria-label="Toggle theme"
            >
              {isDark ? <Sun size={19} /> : <Moon size={19} />}
            </button>

            {/* Notifications */}
            <button className="icon-btn" title="Notifications">
              <Bell size={19} />
              <span className="badge-notification" />
            </button>

            {/* User */}
            <div className="user-profile">
              <div className="avatar">AD</div>
              <div className="user-info">
                <span className="user-name">Administrator</span>
                <span className="user-role">Super Admin</span>
              </div>
            </div>
          </div>
        </header>

        {/* ── Page Content ─── */}
        <div className="admin-content">
          <Outlet />
        </div>
      </main>

      <style>{`
        /* ─── Layout Shell ─── */
        .admin-layout {
          display: flex;
          min-height: 100vh;
          background: var(--background);
          color: var(--text-main);
          transition: background 0.25s ease, color 0.25s ease;
        }

        /* ─── Sidebar ─── */
        .sidebar {
          width: 268px;
          display: flex;
          flex-direction: column;
          position: fixed;
          height: 100vh;
          z-index: 100;
          /* gradient defined in index.css .admin-sidebar */
          transition: width 0.2s ease;
        }

        /* Force sidebar gradient regardless of theme (it's always dark) */
        .admin-sidebar {
          background: linear-gradient(180deg, #04364E 0%, #0C637E 45%, #2496A7 100%) !important;
        }

        .sidebar-header {
          padding: 1.75rem 1.5rem 1.5rem;
          display: flex;
          align-items: center;
          gap: 0.875rem;
          border-bottom: 1px solid rgba(255,255,255,0.10);
        }

        .sidebar-logo {
          width: 40px;
          height: 40px;
          background: rgba(255,255,255,0.12);
          border-radius: 10px;
          display: flex;
          align-items: center;
          justify-content: center;
          flex-shrink: 0;
          backdrop-filter: blur(8px);
        }

        .sidebar-brand {
          display: flex;
          flex-direction: column;
        }

        .brand-name {
          font-size: 1.1rem;
          font-weight: 800;
          color: #ffffff;
          letter-spacing: -0.02em;
          line-height: 1.2;
        }

        .brand-sub {
          font-size: 0.68rem;
          font-weight: 600;
          color: rgba(255,255,255,0.55);
          text-transform: uppercase;
          letter-spacing: 0.08em;
        }

        /* ─── Sidebar Nav ─── */
        .sidebar-nav {
          flex: 1;
          padding: 1.25rem 1rem;
          display: flex;
          flex-direction: column;
          gap: 0.25rem;
          overflow-y: auto;
          scrollbar-width: none;
        }
        .sidebar-nav::-webkit-scrollbar { display: none; }

        .nav-section-label {
          font-size: 0.65rem;
          font-weight: 700;
          color: rgba(255,255,255,0.38);
          text-transform: uppercase;
          letter-spacing: 0.1em;
          padding: 1rem 0.75rem 0.375rem;
          margin-top: 0.25rem;
        }
        .nav-section-label:first-child { padding-top: 0.25rem; }

        .nav-item {
          display: flex;
          align-items: center;
          gap: 0.875rem;
          padding: 0.75rem 0.875rem;
          border-radius: var(--radius-sm);
          color: rgba(255,255,255,0.60);
          font-weight: 600;
          font-size: 0.875rem;
          transition: all 0.18s ease;
          cursor: pointer;
          text-decoration: none;
        }

        .nav-item:hover {
          color: rgba(255,255,255,0.92);
          background: rgba(255,255,255,0.10);
        }

        .nav-item.active {
          color: #ffffff;
          background: rgba(255,255,255,0.18);
          box-shadow: inset 0 0 0 1px rgba(255,255,255,0.15);
        }

        /* ─── Sidebar Footer ─── */
        .sidebar-footer {
          padding: 1.25rem 1rem 1.5rem;
          border-top: 1px solid rgba(255,255,255,0.10);
          display: flex;
          flex-direction: column;
          gap: 0.75rem;
        }

        .sidebar-version {
          font-size: 0.7rem;
          color: rgba(255,255,255,0.35);
          text-align: center;
          font-weight: 600;
          letter-spacing: 0.05em;
        }

        .logout-btn {
          width: 100%;
          display: flex;
          align-items: center;
          gap: 0.875rem;
          padding: 0.75rem 0.875rem;
          background: transparent;
          color: rgba(255, 160, 160, 0.85);
          font-weight: 600;
          font-size: 0.875rem;
          border-radius: var(--radius-sm);
          border: none;
          cursor: pointer;
          transition: all 0.18s ease;
        }

        .logout-btn:hover {
          background: rgba(239, 68, 68, 0.18);
          color: #fca5a5;
        }

        /* ─── Main Content Area ─── */
        .admin-main {
          flex: 1;
          margin-left: 268px;
          display: flex;
          flex-direction: column;
          min-height: 100vh;
        }

        /* ─── Header ─── */
        .admin-header {
          height: 68px;
          background: var(--surface);
          border-bottom: 1px solid var(--border);
          padding: 0 2rem;
          display: flex;
          justify-content: space-between;
          align-items: center;
          position: sticky;
          top: 0;
          z-index: 50;
          transition: background 0.25s ease, border-color 0.25s ease;
          box-shadow: var(--shadow-soft);
        }

        .header-left {
          display: flex;
          align-items: center;
          gap: 1rem;
        }

        .header-search {
          display: flex;
          align-items: center;
          gap: 0.625rem;
          background: var(--input-bg-alt);
          border: 1px solid var(--border);
          border-radius: var(--radius-sm);
          padding: 0.5rem 1rem;
          transition: all 0.2s ease;
        }

        .header-search:focus-within {
          background: var(--input-bg);
          border-color: var(--primary-mid);
          box-shadow: 0 0 0 3px rgba(36,150,167,0.12);
        }

        .header-search input {
          width: 280px;
          background: transparent;
          border: none;
          outline: none;
          font-family: var(--font-sans);
          font-size: 0.875rem;
          color: var(--text-main);
          font-weight: 500;
        }

        .header-search input::placeholder {
          color: var(--text-muted);
        }

        .header-actions {
          display: flex;
          align-items: center;
          gap: 0.75rem;
        }

        .icon-btn {
          position: relative;
          background: var(--surface-raised);
          border: 1px solid var(--border);
          color: var(--text-muted);
          width: 38px;
          height: 38px;
          border-radius: 10px;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          transition: all 0.18s ease;
        }

        .icon-btn:hover {
          background: var(--primary-pale);
          color: var(--primary);
          border-color: var(--primary-mid);
        }

        .theme-toggle {
          color: var(--text-muted);
        }

        .theme-toggle:hover {
          color: var(--primary);
        }

        .badge-notification {
          position: absolute;
          top: 6px;
          right: 6px;
          width: 7px;
          height: 7px;
          background: var(--accent);
          border-radius: 50%;
          border: 2px solid var(--surface);
        }

        .user-profile {
          display: flex;
          align-items: center;
          gap: 0.75rem;
          padding-left: 0.875rem;
          margin-left: 0.25rem;
          border-left: 1px solid var(--border);
          cursor: pointer;
        }

        .avatar {
          width: 36px;
          height: 36px;
          background: linear-gradient(135deg, var(--grad-start), var(--grad-end));
          color: white;
          border-radius: 10px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 0.78rem;
          font-weight: 800;
          flex-shrink: 0;
          letter-spacing: 0.05em;
        }

        .user-info {
          display: flex;
          flex-direction: column;
        }

        .user-name {
          font-size: 0.875rem;
          font-weight: 700;
          color: var(--text-sub);
          line-height: 1.2;
        }

        .user-role {
          font-size: 0.7rem;
          font-weight: 600;
          color: var(--text-muted);
          text-transform: uppercase;
          letter-spacing: 0.06em;
        }

        /* ─── Page Content ─── */
        .admin-content {
          padding: 2rem;
          flex: 1;
          background: var(--background);
          transition: background 0.25s ease;
        }

        /* ─── Fade-in animation ─── */
        @keyframes fadeIn {
          from { opacity: 0; transform: translateY(12px); }
          to   { opacity: 1; transform: translateY(0); }
        }
      `}</style>
    </div>
  );
};

export default AdminLayout;
