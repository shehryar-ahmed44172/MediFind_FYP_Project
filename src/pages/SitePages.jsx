import React, { useRef, useState } from 'react';
import { motion } from 'framer-motion';
import {
  EarOff, HelpCircle, LayoutDashboard, LayoutGrid, ListOrdered, Mail, PlayCircle, Users,
} from 'lucide-react';
import {
  SiteLayout, PageIntro, DeafSection, HowItWorks, Features, Roles, AdminSection, Trust, Faq, Contact, FinalCta,
} from './LandingPage';

/*
 * Separate pages for the site navigation. The home page stays a one-page
 * overview; each page here reuses the same sections under its own title.
 */

/* Chapters of the recorded SOS walkthrough (seconds into the video) */
const VIDEO_CHAPTERS = [
  { at: 0,     who: 'Patient',   text: 'Holds SOS for 2 seconds' },
  { at: 9,     who: 'AI',        text: 'Symptom check suggests Cardiac' },
  { at: 29,    who: 'Patient',   text: 'Sends SOS · 60 s to cancel' },
  { at: 38.8,  who: 'Server',    text: 'Responders and caregiver alerted' },
  { at: 52.8,  who: 'Responder', text: 'Accepts and starts navigating' },
  { at: 60.8,  who: 'Live GPS',  text: 'Ambulance moves on every screen' },
  { at: 118.8, who: 'Responder', text: 'Marks arrived at scene' },
  { at: 130.8, who: 'Resolved',  text: 'Outcome saved, patient rates' },
];

function ProcessVideo() {
  const videoRef = useRef(null);
  const [time, setTime] = useState(0);
  const current = VIDEO_CHAPTERS.reduce((idx, c, i) => (time >= c.at ? i : idx), 0);

  const jump = (at) => {
    const v = videoRef.current;
    if (!v) return;
    v.currentTime = at;
    v.play().catch(() => {});
  };

  return (
    <section className="lp-section lp-section-alt" aria-labelledby="video-title">
      <div className="lp-container">
        <motion.div className="lp-section-head center" initial={{ opacity: 0, y: 18 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.45 }}>
          <span className="lp-eyebrow"><PlayCircle size={14} /> Watch the full process</span>
          <h2 id="video-title">One real SOS, every role, in sync.</h2>
          <p className="lp-lead">
            Recorded from the MediFind apps and admin portal with demo accounts: the patient, the responder,
            the caregiver and the admin all see the same emergency at the same moment.
          </p>
        </motion.div>

        <div className="lp-video-wrap">
          <video
            ref={videoRef}
            src="/videos/medifind-sos-process.mp4"
            poster="/videos/medifind-sos-process.jpg"
            controls
            muted
            playsInline
            preload="metadata"
            onTimeUpdate={e => setTime(e.currentTarget.currentTime)}
            aria-label="Screen recording of one SOS emergency shown on the patient, responder, caregiver and admin screens"
          />
        </div>

        <ol className="lp-video-steps" aria-label="Jump to a step in the video">
          {VIDEO_CHAPTERS.map((c, i) => (
            <li key={c.at}>
              <button type="button" onClick={() => jump(c.at)} aria-current={i === current ? 'true' : undefined}>
                <b aria-hidden="true">{i + 1}</b>
                <span>{c.text}<small>{c.who} · {Math.floor(c.at / 60)}:{String(Math.floor(c.at % 60)).padStart(2, '0')}</small></span>
              </button>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}

export function FeaturesPage() {
  return (
    <SiteLayout subpage>
      <PageIntro eyebrow="Features" Icon={LayoutGrid} title="Everything MediFind does in an emergency.">
        Medical-only SOS, live tracking, in-app calls, AI assistance and privacy that locks when the job is done.
      </PageIntro>
      <Features />
      <Trust />
      <FinalCta />
    </SiteLayout>
  );
}

export function DeafUsersPage() {
  return (
    <SiteLayout subpage>
      <PageIntro eyebrow="For Deaf users" Icon={EarOff} title="Emergency help without hearing or speaking.">
        Every step works by sight and touch: silent SOS, flashing alerts, text chat, quick phrases and video calls.
      </PageIntro>
      <DeafSection />
      <FinalCta />
    </SiteLayout>
  );
}

export function HowItWorksPage() {
  return (
    <SiteLayout subpage>
      <PageIntro eyebrow="How it works" Icon={ListOrdered} title="From tap to treatment.">
        See each step on the phone, then watch a full SOS recorded across every role.
      </PageIntro>
      <HowItWorks />
      <ProcessVideo />
      <FinalCta />
    </SiteLayout>
  );
}

export function RespondersPage() {
  return (
    <SiteLayout subpage>
      <PageIntro eyebrow="Responders" Icon={Users} title="Patients, caregivers and verified responders.">
        One network: patients raise the alert, caregivers stay informed and verified motorbike responders bring help.
      </PageIntro>
      <Roles />
      <Trust />
      <FinalCta />
    </SiteLayout>
  );
}

export function AdminConsolePage() {
  return (
    <SiteLayout subpage>
      <PageIntro eyebrow="Admin console" Icon={LayoutDashboard} title="The control room behind every emergency.">
        Administrators verify responders, monitor live SOS activity and keep every alert and call accountable.
      </PageIntro>
      <AdminSection />
    </SiteLayout>
  );
}

export function FaqPage() {
  return (
    <SiteLayout subpage>
      <PageIntro eyebrow="FAQ" Icon={HelpCircle} title="Questions people ask about MediFind.">
        Can’t find your answer? Send us a message below.
      </PageIntro>
      <Faq />
      <Contact />
    </SiteLayout>
  );
}

export function ContactPage() {
  return (
    <SiteLayout subpage>
      <PageIntro eyebrow="Contact" Icon={Mail} title="Get in touch with the MediFind team.">
        Questions, feedback or responder partnerships — we reply by email.
      </PageIntro>
      <Contact />
    </SiteLayout>
  );
}
