import React, { useEffect } from 'react';
import { motion } from 'framer-motion';
import { Shield, FileText, ChevronLeft, ArrowRight } from 'lucide-react';
import { Link, useLocation } from 'react-router-dom';
import logo from '../assets/medifind_logo_full.png';

const LegalPage = ({ type }) => {
  const { pathname } = useLocation();

  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);

  const isTerms = type === 'terms';
  const title = isTerms ? 'Terms & Conditions' : 'Privacy Policy';
  const lastUpdated = 'May 04, 2026';

  return (
    <div style={{ background: 'var(--surface-alt)', minHeight: '100vh', fontFamily: 'Inter, sans-serif' }}>
      {/* Navbar */}
      <nav style={{ background: 'rgba(255, 255, 255, 0.9)', backdropFilter: 'blur(10px)', position: 'fixed', top: 0, left: 0, right: 0, zIndex: 100, borderBottom: '1px solid var(--border)' }}>
        <div style={{ maxWidth: '1200px', margin: '0 auto', padding: '0.5rem 2rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Link to="/" style={{ display: 'flex', alignItems: 'center', textDecoration: 'none' }}>
            <img src={logo} alt="MediFind" style={{ height: '110px', objectFit: 'contain', display: 'block' }} />
          </Link>
          <Link to="/" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: 'var(--text-sub)', textDecoration: 'none', fontSize: '0.9rem', fontWeight: 600 }}>
            <ChevronLeft size={16} /> <span style={{ opacity: 0.8 }}>Back to Home</span>
          </Link>
        </div>
      </nav>

      {/* Header Area */}
      <div style={{ background: 'linear-gradient(135deg, var(--primary-dark) 0%, var(--primary) 100%)', padding: '10rem 2rem 6rem', color: '#ffffff', textAlign: 'center' }}>
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          style={{ maxWidth: '800px', margin: '0 auto' }}
        >
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.75rem', background: 'rgba(40, 145, 194, 0.15)', border: '1px solid rgba(40, 145, 194, 0.3)', padding: '0.5rem 1.25rem', borderRadius: '100px', color: 'var(--primary-light)', fontSize: '0.875rem', fontWeight: 800, marginBottom: '2rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            {isTerms ? <FileText size={16} /> : <Shield size={16} />}
            Legal Document
          </div>
          <h1 style={{ fontSize: '3.5rem', fontWeight: 800, marginBottom: '1.5rem', letterSpacing: '-0.02em', color: '#ffffff' }}>{title}</h1>
          <p style={{ fontSize: '1.125rem', color: 'var(--border)', lineHeight: 1.6, maxWidth: '600px', margin: '0 auto' }}>
            Last updated: {lastUpdated}. Please read these documents carefully to understand how MediFind operates and protects your data.
          </p>
        </motion.div>
      </div>

      {/* Content Area */}
      <div style={{ maxWidth: '1000px', margin: '-4rem auto 6rem', padding: '0 2rem' }}>
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.2 }}
          style={{ background: 'white', borderRadius: '24px', padding: '4rem', boxShadow: '0 20px 40px rgba(0,0,0,0.05)', border: '1px solid var(--border)' }}
        >
          {isTerms ? (
            <div className="legal-content" style={{ color: 'var(--text-sub)', lineHeight: 1.8 }}>
              <section style={{ marginBottom: '3rem' }}>
                <h2 style={{ color: 'var(--text-main)', fontSize: '1.75rem', marginBottom: '1.5rem' }}>1. Acceptance of Terms</h2>
                <p>By accessing and using MediFind, you agree to be bound by these Terms and Conditions. If you do not agree to all of these terms, do not use the application.</p>
              </section>

              <section style={{ marginBottom: '3rem' }}>
                <h2 style={{ color: 'var(--text-main)', fontSize: '1.75rem', marginBottom: '1.5rem' }}>2. Emergency Response Disclaimer</h2>
                <p>MediFind is a platform that facilitates emergency response by connecting patients with nearby responders. While we strive for maximum reliability, MediFind does not guarantee the arrival, competence, or outcome of any responder. In life-threatening situations, always attempt to contact local emergency services (e.g., 911 or 1122) as a primary or secondary measure.</p>
              </section>

              <section style={{ marginBottom: '3rem' }}>
                <h2 style={{ color: 'var(--text-main)', fontSize: '1.75rem', marginBottom: '1.5rem' }}>3. User Responsibilities</h2>
                <p>Users are responsible for providing accurate personal and medical information. Misuse of the SOS feature (false alarms) may lead to account suspension or legal action. You must be at least 18 years old or have parental consent to use this platform.</p>
              </section>

              <section style={{ marginBottom: '3rem' }}>
                <h2 style={{ color: 'var(--text-main)', fontSize: '1.75rem', marginBottom: '1.5rem' }}>4. Subscription & Payments</h2>
                <p>Access to certain features may require a paid subscription. All payments are non-refundable unless specified otherwise. MediFind reserves the right to modify pricing with prior notice.</p>
              </section>

              <section>
                <h2 style={{ color: 'var(--text-main)', fontSize: '1.75rem', marginBottom: '1.5rem' }}>5. Limitation of Liability</h2>
                <p>To the maximum extent permitted by law, MediFind and its affiliates shall not be liable for any indirect, incidental, special, or consequential damages resulting from the use or inability to use the service.</p>
              </section>
            </div>
          ) : (
            <div className="legal-content" style={{ color: 'var(--text-sub)', lineHeight: 1.8 }}>
              <section style={{ marginBottom: '3rem' }}>
                <h2 style={{ color: 'var(--text-main)', fontSize: '1.75rem', marginBottom: '1.5rem' }}>1. Information We Collect</h2>
                <p>We collect personal identifiers (Name, Email, Phone), precise location data (only during SOS or when responder mode is active), and Protected Health Information (PHI) provided by you in your medical profile.</p>
              </section>

              <section style={{ marginBottom: '3rem' }}>
                <h2 style={{ color: 'var(--text-main)', fontSize: '1.75rem', marginBottom: '1.5rem' }}>2. How We Use Your Data</h2>
                <p>Your data is used strictly for facilitating emergency response. During an active SOS, your location and medical profile (Blood type, Allergies) are shared with assigned responders to enable life-saving interventions.</p>
              </section>

              <section style={{ marginBottom: '3rem' }}>
                <h2 style={{ color: 'var(--text-main)', fontSize: '1.75rem', marginBottom: '1.5rem' }}>3. HIPAA Compliance</h2>
                <p>MediFind adheres to HIPAA standards for the protection of medical records. We implement technical safeguards including end-to-end encryption, automatic session timeouts, and detailed access audit logs.</p>
              </section>

              <section style={{ marginBottom: '3rem' }}>
                <h2 style={{ color: 'var(--text-main)', fontSize: '1.75rem', marginBottom: '1.5rem' }}>4. Data Sharing</h2>
                <p>We do not sell your personal or medical data to third parties. Data is only shared with responders, caregivers (linked by you), and law enforcement when required by law or in life-safety situations.</p>
              </section>

              <section>
                <h2 style={{ color: 'var(--text-main)', fontSize: '1.75rem', marginBottom: '1.5rem' }}>5. Your Rights</h2>
                <p>You have the right to access, rectify, or delete your personal and medical information at any time through the application settings. Deleting your account will result in the permanent removal of your data from our active servers.</p>
              </section>
            </div>
          )}
        </motion.div>

        {/* Footer Link */}
        <div style={{ textAlign: 'center', marginTop: '4rem' }}>
          <p style={{ color: 'var(--text-muted)', fontSize: '1rem', marginBottom: '1.5rem' }}>
            Have questions about our {isTerms ? 'terms' : 'privacy policy'}?
          </p>
          <Link to="/" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.75rem', background: 'var(--primary-light)', color: 'white', padding: '1rem 2.5rem', borderRadius: '14px', fontWeight: 700, textDecoration: 'none', boxShadow: '0 10px 20px rgba(40, 145, 194, 0.2)' }}>
            Contact Support <ArrowRight size={18} />
          </Link>
        </div>
      </div>

      <footer style={{ padding: '4rem 2rem', borderTop: '1px solid var(--border)', textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.875rem' }}>
        &copy; 2026 MediFind Emergency Response Platform. All rights reserved.
      </footer>
    </div>
  );
};

export default LegalPage;
