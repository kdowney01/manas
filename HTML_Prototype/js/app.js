/* ═══════════════════════════════════════════════════════════
   MANAS — Functional HTML Prototype
   Single-file SPA. Works with file:// protocol.
═══════════════════════════════════════════════════════════ */

const App = (() => {

/* ═══════════════════════════════════════
   STATE
═══════════════════════════════════════ */
const state = {
  screen: 'welcome',
  onboardingStep: 0,
  onboardingComplete: false,
  activeTab: 'dashboard',

  // Biometrics (mock — refreshable)
  bio: { hr: 72, hrv: 48, sleep: 7.2, steps: 6421 },
  riskLevel: 'low',   // low | moderate | high | crisis
  wellnessScore: 82,

  // Risk events
  events: [
    { sev: 'moderate', dot: '#FFCC00', triggers: 'Low HRV (28ms) · Low sleep (5.1h)', ago: '2d ago' },
    { sev: 'low',      dot: '#34C759', triggers: 'Elevated HR (91 BPM)',              ago: '5d ago' },
  ],

  // Emergency contacts
  contacts: [
    { name: 'Sarah Downey', phone: '555-0101', rel: 'Spouse', notify: true }
  ],

  // Companion
  persona: 'general',
  messages: [],

  // Digital wellbeing signals (behavioral)
  digital: {
    enabled: false,
    social: true,
    messages: true,
    email: true,
    screentime: true,
    // derived demo values (no raw content — HIPAA)
    screenTimeHrs: 5.4,
    socialMin: 142,
    msgTone: 'Positive',
    emailTone: 'Neutral',
  },

  // Settings
  notificationsEnabled: false,
  calibrationDay: 2,

  // Emergency contact form (temp)
  contactForm: { name: '', phone: '', rel: '' },
};

// Persist & restore
function saveState() {
  try {
    localStorage.setItem('manas_proto_state', JSON.stringify({
      onboardingComplete: state.onboardingComplete,
      contacts: state.contacts,
      persona: state.persona,
      riskLevel: state.riskLevel,
      notificationsEnabled: state.notificationsEnabled,
      digital: state.digital,
    }));
  } catch(e) {}
}
function loadState() {
  try {
    const saved = JSON.parse(localStorage.getItem('manas_proto_state') || '{}');
    Object.assign(state, saved);
  } catch(e) {}
}

/* ═══════════════════════════════════════
   RISK CONFIG
═══════════════════════════════════════ */
const RISK = {
  low:      { label: 'Low',      color: '#34C759', bgColor: 'rgba(52,199,89,0.12)',   wellness: 82 },
  moderate: { label: 'Moderate', color: '#FFCC00', bgColor: 'rgba(255,204,0,0.12)',   wellness: 58 },
  high:     { label: 'High',     color: '#FF9500', bgColor: 'rgba(255,149,0,0.12)',   wellness: 35 },
  crisis:   { label: 'Crisis',   color: '#FF3B30', bgColor: 'rgba(255,59,48,0.10)',   wellness: 12 },
};

function getRisk() { return RISK[state.riskLevel] || RISK.low; }

/* ═══════════════════════════════════════
   PERSONAS & CHAT
═══════════════════════════════════════ */
const PERSONAS = {
  general:  { name: 'Dr. Manas',     icon: '👨‍⚕️', desc: 'General wellness support' },
  cbt:      { name: 'Dr. Chen',      icon: '🧠',  desc: 'Cognitive Behavioral Therapy' },
  anxiety:  { name: 'Dr. Patel',     icon: '🌬️', desc: 'Anxiety & grounding techniques' },
  trauma:   { name: 'Dr. Rivera',    icon: '🛡️', desc: 'Trauma-informed care' },
  stress:   { name: 'Dr. Kim',       icon: '🌿',  desc: 'Stress reduction & resilience' },
  mood:     { name: 'Dr. Osei',      icon: '☀️',  desc: 'Mood tracking & balance' },
};

const RESPONSES = {
  general: {
    default: "Thank you for reaching out. I'm here to listen. How are you feeling right now?",
    keywords: [
      [/sad|depress|hopeless/i, "I hear you. Those feelings are valid and I'm here with you. Would it help to share what's been going on?"],
      [/anxious|worried|panic|overwhelm/i, "Anxiety can feel overwhelming. Let's try slow breathing together — inhale for 4 counts, hold for 4, exhale for 4."],
      [/tired|exhaust|sleep/i, "Sleep affects everything. How have your nights been lately?"],
      [/stress|work|busy/i, "It sounds like you have a lot on your plate. What feels most pressing right now?"],
    ],
  },
  cbt: {
    default: "CBT helps us notice when thoughts might not reflect reality. What thought is troubling you most right now?",
    keywords: [
      [/think|thought|believe|feel like/i, "Let's examine that thought together. What evidence do you have for it — and against it?"],
      [/always|never|everyone|nobody/i, "I notice some all-or-nothing thinking there. Can we look at some exceptions together?"],
      [/can't|impossible|hopeless/i, "That sounds like a thinking trap. What's the most realistic outcome you can imagine?"],
    ],
  },
  anxiety: {
    default: "You're safe here. Let's slow things down together. Can you name 5 things you can see around you right now?",
    keywords: [
      [/panic|can't breathe|heart racing/i, "Let's ground you right now. Place both feet flat on the floor. Take one slow breath in... and out. You're safe."],
      [/worry|what if/i, "Worry loves 'what if' questions. Let's look at what's actually happening right now — just this moment."],
      [/anxious|nervous|scared/i, "Try box breathing with me: breathe in for 4... hold for 4... out for 4... hold for 4. Again."],
    ],
  },
  trauma: {
    default: "You're safe here. We go at whatever pace feels right — there's no pressure to share anything you're not ready for.",
    keywords: [
      [/flashback|nightmare|memory/i, "That sounds really hard. Let's focus on right now. Can you feel your feet on the floor?"],
      [/trust|safe|unsafe/i, "Feeling safe is foundational. What would help you feel more grounded right now?"],
    ],
  },
  stress: {
    default: "Your body and mind both respond to stress. What's feeling heaviest for you right now?",
    keywords: [
      [/work|deadline|pressure|boss/i, "Workplace stress is real. Let's focus on one thing you can set aside just for the next 10 minutes."],
      [/tired|burnout|exhaust/i, "Burnout is a signal worth listening to. When did you last do something just for yourself?"],
      [/meditat|relax|breathe/i, "A 60-second breathing reset can genuinely shift your nervous system. Want to try one together?"],
    ],
  },
  mood: {
    default: "Tracking how you feel helps reveal patterns. On a scale of 1–10, how would you rate today compared to yesterday?",
    keywords: [
      [/happy|good|great|better/i, "That's wonderful to hear. What's contributing to that today?"],
      [/sad|low|down|bad/i, "I'm glad you're here. Low moods often have a cause — sometimes it's sleep, sometimes connection. What feels different today?"],
      [/[1-5]\/10|feel (bad|terrible|awful)/i, "Thank you for sharing that. What's one small thing that usually lifts your mood, even slightly?"],
    ],
  },
};

function getResponse(personaKey, text) {
  const r = RESPONSES[personaKey] || RESPONSES.general;
  for (const [pattern, reply] of r.keywords) {
    if (pattern.test(text)) return reply;
  }
  return r.default;
}

/* ═══════════════════════════════════════
   ROUTER
═══════════════════════════════════════ */
const $ = id => document.getElementById(id);
const screenEl  = () => $('screen');
const navBarEl  = () => $('nav-bar');
const tabBarEl  = () => $('tab-bar');

function navigate(screenId, opts = {}) {
  state.screen = screenId;
  const el = screenEl();
  el.innerHTML = SCREENS[screenId]?.() || `<div style="padding:40px;text-align:center">Screen not found: ${screenId}</div>`;
  el.scrollTop = 0;
  el.classList.remove('screen-animate');
  void el.offsetWidth;
  el.classList.add('screen-animate');

  const isMain = ['dashboard','companion','settings'].includes(screenId);
  const isOnboard = ['welcome','health-access','digital-signals','emergency-contacts','notifications','calibration'].includes(screenId);

  // Nav bar
  const nb = navBarEl();
  if (opts.navTitle) {
    nb.classList.remove('hidden');
    nb.innerHTML = buildNavBar(opts);
  } else if (screenId === 'dashboard') {
    nb.classList.remove('hidden');
    nb.classList.add('large-title');
    nb.innerHTML = `
      <img src="assets/manas_logo.png" class="nav-logo" alt="manas"/>
      <button class="nav-btn" id="refresh-btn" title="Refresh">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round">
          <polyline points="23 4 23 10 17 10"/>
          <path d="M20.49 15a9 9 0 1 1-.02-3.79"/>
        </svg>
      </button>`;
    nb.classList.remove('hidden');
  } else {
    nb.innerHTML = '';
    nb.classList.add('hidden');
    nb.classList.remove('large-title');
  }

  // Tab bar
  if (isMain) {
    tabBarEl().classList.remove('hidden');
    document.querySelectorAll('.tab').forEach(t => {
      t.classList.toggle('active', t.dataset.tab === screenId);
    });
    state.activeTab = screenId;
  } else {
    tabBarEl().classList.add('hidden');
  }

  bindScreenEvents(screenId);
  updateDevState();
  saveState();
}

function buildNavBar({ navTitle, navBack, backTarget }) {
  return `
    ${navBack ? `<button class="nav-back" data-goto="${backTarget}">‹ ${navBack}</button>` : '<div></div>'}
    <div class="nav-title">${navTitle}</div>
    <div></div>`;
}

function switchTab(tab) {
  navigate(tab);
}

/* ═══════════════════════════════════════
   SCREENS
═══════════════════════════════════════ */
const SCREENS = {

  /* ── Welcome ── */
  'welcome': () => `
    <div class="onboard-screen">
      <div class="onboard-top">
        <img src="assets/manas_logo.png" class="welcome-logo" alt="manas"/>
        <div class="onboard-sub" style="margin-top:8px;">
          Manas passively monitors your wellbeing using health signals already collected by your iPhone — no effort required.
        </div>
        <div class="onboard-caption">Private · Always-on · On-device</div>
      </div>
      <div class="onboard-bottom">
        <div style="display:flex;justify-content:center;margin-bottom:12px;">
          ${[0,1,2,3,4,5].map(i=>`<div class="step-dot${i===0?' active':''}" style="margin:0 3px"></div>`).join('')}
        </div>
        <button class="btn btn-primary" data-goto="health-access">Get Started</button>
        <button class="btn btn-ghost" onclick="App.showLearnMore()">Learn how it works</button>
      </div>
    </div>`,

  /* ── Health Access ── */
  'health-access': () => `
    <div class="onboard-screen">
      <div class="onboard-top">
        <div class="onboard-icon" style="background:rgba(255,59,48,0.10)">❤️</div>
        <div class="onboard-title">Health Access</div>
        <div class="onboard-sub">Manas reads signals already on your iPhone. Nothing is sent anywhere without your permission.</div>
        <div style="width:100%;display:flex;flex-direction:column;gap:8px;margin-top:4px;">
          <div class="perm-row">
            <div class="perm-icon" style="background:rgba(92,108,179,0.12)">❤️</div>
            <div><div class="perm-name">Heart Rate &amp; HRV</div><div class="perm-desc">Stress detection &amp; baseline tracking</div></div>
          </div>
          <div class="perm-row">
            <div class="perm-icon" style="background:rgba(173,108,173,0.12)">🌙</div>
            <div><div class="perm-name">Sleep</div><div class="perm-desc">Recovery patterns</div></div>
          </div>
          <div class="perm-row">
            <div class="perm-icon" style="background:rgba(52,199,89,0.12)">🚶</div>
            <div><div class="perm-name">Activity</div><div class="perm-desc">Behavioral change detection</div></div>
          </div>
        </div>
        <div class="onboard-caption">All processing happens on-device using Apple's HealthKit. Raw data never leaves your iPhone.</div>
      </div>
      <div class="onboard-bottom">
        <div style="display:flex;justify-content:center;margin-bottom:12px;">
          ${[0,1,2,3,4,5].map(i=>`<div class="step-dot${i===1?' active':''}" style="margin:0 3px"></div>`).join('')}
        </div>
        <button class="btn btn-primary" data-goto="digital-signals">Allow Health Access</button>
      </div>
    </div>`,

  /* ── Digital Wellbeing ── */
  'digital-signals': () => `
    <div class="onboard-screen">
      <div class="onboard-top">
        <div class="onboard-icon" style="background:rgba(173,108,173,0.12)">📲</div>
        <div class="onboard-title">Digital Wellbeing</div>
        <div class="onboard-sub">Your phone habits reveal early shifts in mood and energy. Manas reads the <em>patterns</em> — never the content.</div>
        <div style="width:100%;display:flex;flex-direction:column;gap:8px;margin-top:4px;">
          ${digitalSignalRow('ds-social','📲','var(--indigo-l)','Social Media','Engagement &amp; usage patterns', state.digital.social)}
          ${digitalSignalRow('ds-messages','💬','var(--lav-l)','Message Tone','Sentiment from texts — on-device only', state.digital.messages)}
          ${digitalSignalRow('ds-email','✉️','rgba(255,179,151,0.18)','Email Tone','Sentiment from email — on-device only', state.digital.email)}
          ${digitalSignalRow('ds-screentime','⏱️','rgba(168,230,207,0.30)','Screen Time','Daily totals &amp; late-night use', state.digital.screentime)}
        </div>
        <div class="onboard-caption">Only derived scores (tone, frequency, duration) are computed — on-device. Raw messages, emails, and content are never stored or transmitted. HIPAA-safe.</div>
      </div>
      <div class="onboard-bottom">
        <div style="display:flex;justify-content:center;margin-bottom:12px;">
          ${[0,1,2,3,4,5].map(i=>`<div class="step-dot${i===2?' active':''}" style="margin:0 3px"></div>`).join('')}
        </div>
        <button class="btn btn-primary" id="ds-continue-btn">Enable &amp; Continue</button>
        <button class="btn btn-ghost" data-goto="emergency-contacts">Skip for now</button>
      </div>
    </div>`,

  /* ── Emergency Contacts ── */
  'emergency-contacts': () => `
    <div class="onboard-screen">
      <div class="onboard-top">
        <div class="onboard-icon" style="background:rgba(92,108,179,0.12)">👥</div>
        <div class="onboard-title">Emergency Contacts</div>
        <div class="onboard-sub">If Manas detects a crisis, it can alert someone you trust. You can add or change contacts any time.</div>
        <div style="width:100%;display:flex;flex-direction:column;gap:10px;">
          <input class="sheet-input" placeholder="Full name" id="ec-name" value="${state.contactForm.name}"/>
          <input class="sheet-input" placeholder="Phone number" id="ec-phone" type="tel" value="${state.contactForm.phone}"/>
          <input class="sheet-input" placeholder="Relationship (e.g. Spouse, Friend)" id="ec-rel" value="${state.contactForm.rel}"/>
        </div>
        <div class="onboard-caption" style="margin-top:4px;">Contact info is stored only on your device. It is never uploaded.</div>
      </div>
      <div class="onboard-bottom">
        <div style="display:flex;justify-content:center;margin-bottom:12px;">
          ${[0,1,2,3,4,5].map(i=>`<div class="step-dot${i===3?' active':''}" style="margin:0 3px"></div>`).join('')}
        </div>
        <button class="btn btn-primary" id="ec-save-btn">Save &amp; Continue</button>
        <button class="btn btn-ghost" data-goto="notifications">Skip for now</button>
      </div>
    </div>`,

  /* ── Notifications ── */
  'notifications': () => `
    <div class="onboard-screen">
      <div class="onboard-top">
        <div class="onboard-icon" style="background:rgba(173,108,173,0.12)">🔔</div>
        <div class="onboard-title">Stay Informed</div>
        <div class="onboard-sub">Manas sends gentle nudges when your signals shift, and critical alerts during a crisis.</div>
        <div style="width:100%;display:flex;flex-direction:column;gap:8px;margin-top:4px;">
          <div class="perm-row">
            <div class="perm-icon" style="background:rgba(255,204,0,0.12)">🔔</div>
            <div><div class="perm-name">Wellbeing nudges</div><div class="perm-desc">Gentle check-in at High risk level</div></div>
          </div>
          <div class="perm-row">
            <div class="perm-icon" style="background:rgba(255,59,48,0.10)">🚨</div>
            <div><div class="perm-name">Crisis alerts</div><div class="perm-desc">Immediate support at Crisis level</div></div>
          </div>
        </div>
        <div class="onboard-caption">No PHI in notification content — HIPAA safe.</div>
      </div>
      <div class="onboard-bottom">
        <div style="display:flex;justify-content:center;margin-bottom:12px;">
          ${[0,1,2,3,4,5].map(i=>`<div class="step-dot${i===4?' active':''}" style="margin:0 3px"></div>`).join('')}
        </div>
        <button class="btn btn-primary" id="notif-enable-btn">Enable Notifications</button>
        <button class="btn btn-ghost" data-goto="calibration">Skip for now</button>
      </div>
    </div>`,

  /* ── Calibration ── */
  'calibration': () => `
    <div class="onboard-screen">
      <div class="onboard-top">
        <div class="onboard-icon" style="background:rgba(92,108,179,0.12)">📈</div>
        <div class="onboard-title">Learning Your Baseline</div>
        <div class="onboard-sub">Manas spends 7 days learning what's normal for you — so it can detect meaningful changes, not noise.</div>
        <div style="width:100%;">
          <div class="day-track" style="margin:8px 0 12px;">
            ${['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map((d,i) => `
              ${i > 0 ? `<div class="day-conn${i <= state.calibrationDay - 1 ? ' done' : ''}"></div>` : ''}
              <div class="day-item">
                <div class="day-dot-el${i < state.calibrationDay - 1 ? ' done' : i === state.calibrationDay - 1 ? ' today' : ''}">${i < state.calibrationDay - 1 ? '✓' : i + 1}</div>
                <div class="day-lbl-el${i < state.calibrationDay - 1 ? ' done' : i === state.calibrationDay - 1 ? ' today' : ''}">${d}</div>
              </div>`).join('')}
          </div>
          <div class="prog-bar"><div class="prog-fill" style="width:${Math.round((state.calibrationDay/7)*100)}%"></div></div>
          <div class="prog-labels"><span>Day ${state.calibrationDay} of 7</span><span>${Math.round((state.calibrationDay/7)*100)}% complete</span></div>
        </div>
        <div class="onboard-caption">Risk scoring activates automatically after your baseline is complete. No action needed from you.</div>
      </div>
      <div class="onboard-bottom">
        <div style="display:flex;justify-content:center;margin-bottom:12px;">
          ${[0,1,2,3,4,5].map(i=>`<div class="step-dot${i===5?' active':''}" style="margin:0 3px"></div>`).join('')}
        </div>
        <button class="btn btn-primary" id="start-btn">Start Manas</button>
      </div>
    </div>`,

  /* ── Dashboard ── */
  'dashboard': () => {
    const risk = getRisk();
    const arc = Math.round((state.wellnessScore / 100) * 326.7);
    const gap = 326.7 - arc;
    return `
    <div class="dashboard screen-animate">
      <div>
        <div class="greeting-hi">Good morning, Kyle 👋</div>
        <div class="greeting-date">${formatDate()} · Updated just now</div>
      </div>

      <!-- Wellness ring -->
      <div class="card ring-card">
        <div class="ring-eyebrow">Wellbeing Score</div>
        <div class="ring-body">
          <svg width="100" height="100" viewBox="0 0 120 120">
            <circle cx="60" cy="60" r="52" fill="none" stroke="#E5E5EA" stroke-width="8"/>
            <circle cx="60" cy="60" r="52" fill="none"
              stroke="${risk.color}" stroke-width="8"
              stroke-dasharray="${arc} ${gap}"
              stroke-linecap="round"
              class="ring-progress"
              transform="rotate(-90 60 60)"/>
            <text x="60" y="54" text-anchor="middle" font-family="Montserrat,sans-serif" font-weight="800" font-size="26" fill="#1C1C1E">${state.wellnessScore}</text>
            <text x="60" y="70" text-anchor="middle" font-family="Montserrat,sans-serif" font-weight="600" font-size="9" fill="#AEAEB2" letter-spacing="1">OF 100</text>
          </svg>
          <div class="ring-info">
            <div class="ring-status" style="background:${risk.bgColor};color:${risk.color}">
              <svg width="7" height="7"><circle cx="3.5" cy="3.5" r="3.5" fill="${risk.color}"/></svg>
              ${risk.label} Risk
            </div>
            <div class="ring-detail">All signals within your personal baseline range.</div>
            <div class="ring-metrics">HRV <span>${state.bio.hrv}ms</span> · HR <span>${state.bio.hr} BPM</span></div>
          </div>
        </div>
      </div>

      <!-- Biometric grid -->
      <div class="bio-grid">
        ${metricTile('❤️','rgba(255,59,48,0.09)', state.bio.hr + ' BPM', 'Heart Rate', '→ stable', 'flat')}
        ${metricTile('〰️','rgba(173,108,173,0.09)', state.bio.hrv + ' ms', 'HRV', '↑ +18%', 'up')}
        ${metricTile('🌙','rgba(92,108,179,0.09)', state.bio.sleep + 'h', 'Sleep', '↑ good', 'up')}
        ${metricTile('🚶','rgba(52,199,89,0.09)', state.bio.steps.toLocaleString(), 'Steps', '→ avg', 'flat')}
      </div>

      <!-- Digital wellbeing -->
      ${digitalSection()}

      <!-- Insight card -->
      <div class="insight-card" id="insight-tap">
        <div class="insight-header">
          <span style="font-size:14px">💡</span>
          <span class="insight-label">Daily Insight</span>
        </div>
        <div class="insight-text">Your HRV is 18% above your 7-day average. Combined with consistent sleep, you're in a positive recovery window. <span style="color:var(--indigo);font-weight:600">Talk to your companion →</span></div>
      </div>

      <!-- Alerts -->
      <div>
        <div class="alerts-hd">Recent Alerts</div>
        <div style="display:flex;flex-direction:column;gap:7px;">
          ${state.events.map(e => `
            <div class="alert-row">
              <div class="alert-dot" style="background:${e.dot}"></div>
              <div>
                <div class="alert-sev">${e.sev.charAt(0).toUpperCase()+e.sev.slice(1)}</div>
                <div class="alert-trig">${e.triggers}</div>
              </div>
              <div class="alert-time">${e.ago}</div>
            </div>`).join('')}
        </div>
      </div>
    </div>`;
  },

  /* ── Companion ── */
  'companion': () => {
    const p = PERSONAS[state.persona];
    return `
    <div class="companion-wrap">
      <!-- Persona bar -->
      <div class="persona-bar">
        ${Object.entries(PERSONAS).map(([key, p]) => `
          <button class="persona-chip${state.persona === key ? ' active' : ''}" data-persona="${key}">
            ${p.icon} ${p.name}
          </button>`).join('')}
      </div>

      <!-- Chat messages -->
      <div class="chat-area" id="chat-area">
        ${state.messages.length === 0 ? renderMsg('ai', p.icon, `Hi, I'm ${p.name}. ${p.desc}. What's on your mind today?`) : ''}
        ${state.messages.map(m => renderMsg(m.role, m.role === 'ai' ? p.icon : null, m.text)).join('')}
      </div>

      <!-- Input bar -->
      <div class="chat-input-bar">
        <textarea class="chat-input" id="chat-input" placeholder="Message ${p.name}…" rows="1"></textarea>
        <button class="chat-send" id="chat-send" disabled>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="white">
            <path d="M22 2L11 13M22 2L15 22l-4-9-9-4 20-7z"/>
          </svg>
        </button>
      </div>
    </div>`;
  },

  /* ── Settings ── */
  'settings': () => `
    <div class="settings-body">
      <!-- Emergency contacts -->
      <div class="section-hd">Emergency Contacts</div>
      <div class="list-section" style="margin:0 16px;">
        ${state.contacts.length === 0
          ? `<div class="list-row"><div class="list-row-label" style="color:var(--ios-l3)">No contacts added yet</div></div>`
          : state.contacts.map((c,i) => `
            <div class="settings-contact-row">
              <div>
                <div class="settings-contact-name">${c.name}</div>
                <div class="settings-contact-rel">${c.rel} · ${c.phone}</div>
              </div>
              <button class="settings-contact-del" data-del-contact="${i}">Remove</button>
            </div>`).join('')}
        <div class="list-row">
          <button style="color:var(--indigo);font-size:15px;font-weight:600;font-family:var(--font);" id="add-contact-btn">+ Add Contact</button>
        </div>
      </div>

      <!-- Notifications -->
      <div class="section-hd">Notifications</div>
      <div class="list-section" style="margin:0 16px;">
        <div class="list-row">
          <div class="list-row-icon">🔔</div>
          <div class="list-row-content"><div class="list-row-label">Wellbeing nudges &amp; alerts</div></div>
          <label class="toggle">
            <input type="checkbox" id="notif-toggle" ${state.notificationsEnabled ? 'checked' : ''}>
            <div class="toggle-track"></div>
            <div class="toggle-thumb"></div>
          </label>
        </div>
      </div>

      <!-- Digital signals -->
      <div class="section-hd">Digital Signals</div>
      <div class="list-section" style="margin:0 16px;">
        <div class="list-row">
          <div class="list-row-icon">📲</div>
          <div class="list-row-content">
            <div class="list-row-label">Behavioral signals</div>
            <div class="list-row-detail">Social, messages, email tone, screen time</div>
          </div>
          <label class="toggle">
            <input type="checkbox" id="digital-toggle" ${state.digital.enabled ? 'checked' : ''}>
            <div class="toggle-track"></div>
            <div class="toggle-thumb"></div>
          </label>
        </div>
      </div>

      <!-- Privacy -->
      <div class="section-hd">Privacy</div>
      <div class="list-section" style="margin:0 16px;">
        <div class="privacy-badge">All data processed on-device</div>
        <div class="privacy-badge">HealthKit data never transmitted raw</div>
        <div class="privacy-badge">Keychain-encrypted contact storage</div>
        <div class="privacy-badge">No advertising or analytics SDKs</div>
      </div>

      <!-- Your data -->
      <div class="section-hd">Your Data</div>
      <div class="list-section" style="margin:0 16px;">
        <div class="list-row" id="export-btn" style="cursor:pointer;">
          <div class="list-row-icon">📤</div>
          <div class="list-row-content"><div class="list-row-label" style="color:var(--indigo)">Export My Data</div></div>
        </div>
        <div class="list-row" id="delete-btn" style="cursor:pointer;">
          <div class="list-row-icon">🗑</div>
          <div class="list-row-content"><div class="list-row-label" style="color:var(--risk-crisis)">Delete All Data</div></div>
        </div>
      </div>

      <!-- About -->
      <div class="section-hd">About</div>
      <div class="list-section" style="margin:0 16px;">
        <div class="list-row"><div class="list-row-content"><div class="list-row-label">Version</div></div><div class="list-row-trail">0.1.0-prototype</div></div>
        <div class="list-row" style="cursor:pointer;"><div class="list-row-content"><div class="list-row-label" style="color:var(--indigo)">Privacy Policy</div></div><div class="list-row-trail">›</div></div>
        <div class="list-row" style="cursor:pointer;"><div class="list-row-content"><div class="list-row-label" style="color:var(--indigo)">Terms of Service</div></div><div class="list-row-trail">›</div></div>
      </div>
    </div>`,

  /* ── Crisis ── */
  'crisis': () => `
    <div class="crisis-screen">
      <div class="crisis-header">
        <div class="crisis-header-icon">💙</div>
        <div class="crisis-header-title">You're not alone</div>
        <div class="crisis-header-sub">Manas detected signals that may indicate you need support right now. Help is available immediately.</div>
      </div>

      <!-- 988 -->
      <div class="card crisis-card">
        <div class="crisis-card-label">📞 988 Crisis Lifeline</div>
        <div class="crisis-card-sub">Free, confidential support 24/7. Call or text 988 to reach the Suicide &amp; Crisis Lifeline.</div>
        <div class="crisis-btn-row">
          <button class="btn btn-danger btn-sm" style="flex:1;padding:13px;" id="call-988">Call 988</button>
          <button class="btn btn-red-ghost btn-sm" style="flex:1;padding:13px;" id="text-988">Text 988</button>
        </div>
      </div>

      <!-- Emergency contacts -->
      ${state.contacts.length > 0 ? `
      <div class="card crisis-card">
        <div class="crisis-card-label">👥 Alert Your Contacts</div>
        <div style="display:flex;flex-direction:column;gap:8px;">
          ${state.contacts.map((c,i) => `
            <div style="display:flex;align-items:center;justify-content:space-between;padding:10px 0;border-bottom:1px solid var(--ios-sep);">
              <div>
                <div style="font-size:14px;font-weight:600;color:var(--ios-l1);">${c.name}</div>
                <div style="font-size:12px;color:var(--ios-l2);">${c.rel}</div>
              </div>
              <button class="btn btn-primary btn-sm" data-text-contact="${i}">Text</button>
            </div>`).join('')}
          <button class="btn btn-danger" style="margin-top:4px;" id="alert-all-btn">Alert All Contacts</button>
        </div>
      </div>` : ''}

      <!-- Companion -->
      <div class="card crisis-card" id="crisis-companion" style="cursor:pointer;">
        <div class="crisis-card-label">💬 Talk to Your AI Companion</div>
        <div class="crisis-card-sub">Your companion is ready to listen and guide you through grounding techniques.</div>
      </div>

      <div class="dismiss-link" id="crisis-dismiss">I'm safe — dismiss</div>
    </div>`,
};

/* ═══════════════════════════════════════
   SCREEN HELPERS
═══════════════════════════════════════ */
function metricTile(icon, iconBg, val, label, trend, trendType) {
  return `<div class="metric-tile">
    <div class="metric-icon-row">
      <div class="metric-ico" style="background:${iconBg}">${icon}</div>
      <div class="metric-trend trend-${trendType}">${trend}</div>
    </div>
    <div class="metric-val">${val}</div>
    <div class="metric-lbl">${label}</div>
  </div>`;
}

function digitalSignalRow(id, icon, iconBg, name, desc, checked) {
  return `<div class="perm-row">
    <div class="perm-icon" style="background:${iconBg}">${icon}</div>
    <div style="flex:1">
      <div class="perm-name">${name}</div>
      <div class="perm-desc">${desc}</div>
    </div>
    <label class="toggle">
      <input type="checkbox" id="${id}" ${checked ? 'checked' : ''}>
      <div class="toggle-track"></div>
      <div class="toggle-thumb"></div>
    </label>
  </div>`;
}

function digitalSection() {
  const d = state.digital;
  if (!d.enabled) {
    return `
      <div>
        <div class="alerts-hd">Digital Wellbeing</div>
        <div class="digital-prompt" id="digital-enable-prompt">
          <div class="digital-prompt-icon">📲</div>
          <div style="flex:1">
            <div class="digital-prompt-title">Add digital signals</div>
            <div class="digital-prompt-sub">Screen time, social, and message tone sharpen your wellbeing score.</div>
          </div>
          <div style="color:var(--indigo);font-weight:700;font-size:22px;line-height:1;">+</div>
        </div>
      </div>`;
  }
  const tiles = [];
  if (d.screentime) tiles.push(metricTile('⏱️','rgba(92,108,179,0.09)', d.screenTimeHrs + 'h', 'Screen Time', '→ typical', 'flat'));
  if (d.social)     tiles.push(metricTile('📲','rgba(173,108,173,0.09)', d.socialMin + 'm', 'Social Media', '→ stable', 'flat'));
  if (d.messages)   tiles.push(metricTile('💬','rgba(52,199,89,0.09)', d.msgTone, 'Message Tone', '↑ warmer', 'up'));
  if (d.email)      tiles.push(metricTile('✉️','rgba(255,179,151,0.18)', d.emailTone, 'Email Tone', '→ steady', 'flat'));
  if (tiles.length === 0) return '';
  return `
    <div>
      <div class="alerts-hd">Digital Wellbeing</div>
      <div class="bio-grid">${tiles.join('')}</div>
      <div class="digital-note">📲 Tone is computed on-device from language patterns. Raw message &amp; email content is never stored or sent.</div>
    </div>`;
}

function renderMsg(role, icon, text) {
  return `<div class="msg ${role}">
    ${role === 'ai' ? `<div class="msg-avatar">${icon}</div>` : ''}
    <div class="msg-bubble">${text}</div>
  </div>`;
}

function formatDate() {
  return new Date().toLocaleDateString('en-US', { weekday:'long', month:'long', day:'numeric' });
}

/* ═══════════════════════════════════════
   SCREEN EVENT BINDING
═══════════════════════════════════════ */
function bindScreenEvents(screenId) {
  // Universal [data-goto] buttons
  document.querySelectorAll('[data-goto]').forEach(el => {
    el.addEventListener('click', () => navigate(el.dataset.goto));
  });

  switch (screenId) {

    case 'digital-signals':
      document.getElementById('ds-continue-btn')?.addEventListener('click', () => {
        state.digital.social     = document.getElementById('ds-social').checked;
        state.digital.messages   = document.getElementById('ds-messages').checked;
        state.digital.email      = document.getElementById('ds-email').checked;
        state.digital.screentime = document.getElementById('ds-screentime').checked;
        state.digital.enabled    = true;
        saveState();
        navigate('emergency-contacts');
      });
      break;

    case 'emergency-contacts':
      document.getElementById('ec-save-btn')?.addEventListener('click', () => {
        const name  = document.getElementById('ec-name').value.trim();
        const phone = document.getElementById('ec-phone').value.trim();
        const rel   = document.getElementById('ec-rel').value.trim();
        if (name && phone) {
          state.contacts.push({ name, phone, rel: rel || 'Contact', notify: false });
        }
        navigate('notifications');
      });
      break;

    case 'notifications':
      document.getElementById('notif-enable-btn')?.addEventListener('click', () => {
        state.notificationsEnabled = true;
        navigate('calibration');
      });
      break;

    case 'calibration':
      document.getElementById('start-btn')?.addEventListener('click', () => {
        state.onboardingComplete = true;
        saveState();
        navigate('dashboard');
      });
      break;

    case 'dashboard':
      document.getElementById('refresh-btn')?.addEventListener('click', refreshBiometrics);
      document.getElementById('insight-tap')?.addEventListener('click', () => switchTab('companion'));
      document.getElementById('digital-enable-prompt')?.addEventListener('click', showDigitalSheet);
      break;

    case 'companion':
      const input  = document.getElementById('chat-input');
      const sendBtn = document.getElementById('chat-send');

      // Persona chips
      document.querySelectorAll('[data-persona]').forEach(btn => {
        btn.addEventListener('click', () => {
          state.persona = btn.dataset.persona;
          state.messages = [];
          navigate('companion');
        });
      });

      // Auto-resize textarea
      input?.addEventListener('input', () => {
        input.style.height = 'auto';
        input.style.height = Math.min(input.scrollHeight, 96) + 'px';
        sendBtn.disabled = input.value.trim() === '';
      });

      // Send on Enter (not Shift+Enter)
      input?.addEventListener('keydown', e => {
        if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
      });

      sendBtn?.addEventListener('click', sendMessage);

      // Scroll chat to bottom
      const chatArea = document.getElementById('chat-area');
      if (chatArea) chatArea.scrollTop = chatArea.scrollHeight;
      break;

    case 'settings':
      document.getElementById('add-contact-btn')?.addEventListener('click', showAddContactSheet);
      document.getElementById('notif-toggle')?.addEventListener('change', e => {
        state.notificationsEnabled = e.target.checked;
        saveState();
      });
      document.getElementById('digital-toggle')?.addEventListener('change', e => {
        if (e.target.checked) {
          state.digital.enabled = true;
          state.digital.social = state.digital.messages = state.digital.email = state.digital.screentime = true;
        } else {
          state.digital.enabled = false;
        }
        saveState();
      });
      document.querySelectorAll('[data-del-contact]').forEach(btn => {
        btn.addEventListener('click', () => {
          const i = parseInt(btn.dataset.delContact);
          if (confirm(`Remove ${state.contacts[i]?.name}?`)) {
            state.contacts.splice(i, 1);
            navigate('settings');
          }
        });
      });
      document.getElementById('export-btn')?.addEventListener('click', () => {
        alert('Data export ready.\n\nIn the real app this produces a JSON file with your anonymized wellbeing history (no raw PHI).');
      });
      document.getElementById('delete-btn')?.addEventListener('click', () => {
        if (confirm('Delete all Manas data? This cannot be undone.\n\nThis will clear your baseline, risk history, and contacts.')) {
          state.contacts = [];
          state.messages = [];
          state.onboardingComplete = false;
          state.digital.enabled = false;
          localStorage.removeItem('manas_proto_state');
          navigate('welcome');
        }
      });
      break;

    case 'crisis':
      document.getElementById('call-988')?.addEventListener('click', () =>
        alert('In the real app this opens the Phone dialer with 988 pre-dialed.'));
      document.getElementById('text-988')?.addEventListener('click', () =>
        alert('In the real app this opens Messages with 988 as the recipient.'));
      document.getElementById('alert-all-btn')?.addEventListener('click', () =>
        alert(`SMS drafted to all ${state.contacts.length} emergency contact(s).\n\nIn the real app this opens MFMessageComposeViewController.`));
      document.querySelectorAll('[data-text-contact]').forEach(btn => {
        btn.addEventListener('click', () => {
          const c = state.contacts[parseInt(btn.dataset.textContact)];
          alert(`In the real app this opens Messages to ${c?.name} (${c?.phone}).`);
        });
      });
      document.getElementById('crisis-companion')?.addEventListener('click', () => switchTab('companion'));
      document.getElementById('crisis-dismiss')?.addEventListener('click', () => switchTab('dashboard'));
      break;
  }
}

/* ═══════════════════════════════════════
   COMPANION CHAT
═══════════════════════════════════════ */
function sendMessage() {
  const input = document.getElementById('chat-input');
  const text  = input?.value.trim();
  if (!text) return;

  state.messages.push({ role: 'user', text });
  input.value = '';
  input.style.height = 'auto';
  document.getElementById('chat-send').disabled = true;

  // Re-render chat area with typing indicator
  const chatArea = document.getElementById('chat-area');
  const p = PERSONAS[state.persona];
  chatArea.innerHTML =
    state.messages.map(m => renderMsg(m.role, m.role === 'ai' ? p.icon : null, m.text)).join('') +
    `<div class="msg ai" id="typing-row">
      <div class="msg-avatar">${p.icon}</div>
      <div class="msg-bubble" style="padding:14px 16px;">
        <div class="typing">
          <div class="typing-dot"></div><div class="typing-dot"></div><div class="typing-dot"></div>
        </div>
      </div>
    </div>`;
  chatArea.scrollTop = chatArea.scrollHeight;

  // Simulate response delay
  const delay = 1000 + Math.random() * 1200;
  setTimeout(() => {
    const reply = getResponse(state.persona, text);
    state.messages.push({ role: 'ai', text: reply });

    chatArea.innerHTML =
      state.messages.map(m => renderMsg(m.role, m.role === 'ai' ? p.icon : null, m.text)).join('');
    chatArea.scrollTop = chatArea.scrollHeight;
  }, delay);
}

/* ═══════════════════════════════════════
   SHEETS / MODALS
═══════════════════════════════════════ */
function showSheet(html) {
  const overlay = $('modal-overlay');
  const sheet   = $('modal-sheet');
  overlay.classList.remove('hidden');
  sheet.classList.remove('hidden');
  sheet.innerHTML = html;
  overlay.onclick = hideSheet;
}
function hideSheet() {
  $('modal-overlay').classList.add('hidden');
  $('modal-sheet').classList.add('hidden');
}

function showAddContactSheet() {
  showSheet(`
    <div class="sheet-handle"></div>
    <button class="sheet-close" onclick="App.hideSheet()">×</button>
    <div class="sheet-title">Add Emergency Contact</div>
    <input class="sheet-input" id="s-name" placeholder="Full name">
    <input class="sheet-input" id="s-phone" placeholder="Phone number" type="tel">
    <input class="sheet-input" id="s-rel"   placeholder="Relationship (e.g. Spouse, Friend)">
    <label style="display:flex;align-items:center;gap:10px;margin:6px 0 16px;font-size:14px;color:var(--ios-l1);">
      <label class="toggle" style="position:relative;">
        <input type="checkbox" id="s-notify">
        <div class="toggle-track"></div>
        <div class="toggle-thumb"></div>
      </label>
      Notify at High risk (always at Crisis)
    </label>
    <button class="btn btn-primary" id="s-save">Save Contact</button>
    <div class="sheet-cancel" onclick="App.hideSheet()">Cancel</div>
  `);
  document.getElementById('s-save')?.addEventListener('click', () => {
    const name  = document.getElementById('s-name').value.trim();
    const phone = document.getElementById('s-phone').value.trim();
    const rel   = document.getElementById('s-rel').value.trim();
    const notify = document.getElementById('s-notify').checked;
    if (name && phone) {
      state.contacts.push({ name, phone, rel: rel || 'Contact', notify });
      hideSheet();
      navigate('settings');
    } else {
      document.getElementById('s-name').style.border = name ? '' : '2px solid var(--risk-crisis)';
      document.getElementById('s-phone').style.border = phone ? '' : '2px solid var(--risk-crisis)';
    }
  });
}

function showDigitalSheet() {
  const d = state.digital;
  showSheet(`
    <div class="sheet-handle"></div>
    <button class="sheet-close" onclick="App.hideSheet()">×</button>
    <div class="sheet-title">Digital Signals</div>
    <div style="font-size:13px;color:var(--ios-l2);line-height:1.5;margin:-8px 0 16px;text-align:center;">
      Manas analyzes behavioral <em>patterns</em> — not content — to detect early changes in your wellbeing.
    </div>
    <div style="display:flex;flex-direction:column;gap:8px;margin-bottom:16px;">
      ${digitalSignalRow('dsheet-social','📲','var(--indigo-l)','Social Media','Engagement &amp; usage patterns', d.social)}
      ${digitalSignalRow('dsheet-messages','💬','var(--lav-l)','Message Tone','On-device sentiment only', d.messages)}
      ${digitalSignalRow('dsheet-email','✉️','rgba(255,179,151,0.18)','Email Tone','On-device sentiment only', d.email)}
      ${digitalSignalRow('dsheet-screentime','⏱️','rgba(168,230,207,0.30)','Screen Time','Daily totals &amp; late-night use', d.screentime)}
    </div>
    <button class="btn btn-primary" id="dsheet-save">Enable Digital Signals</button>
    <div class="sheet-cancel" onclick="App.hideSheet()">Not now</div>
  `);
  document.getElementById('dsheet-save')?.addEventListener('click', () => {
    state.digital.social     = document.getElementById('dsheet-social').checked;
    state.digital.messages   = document.getElementById('dsheet-messages').checked;
    state.digital.email      = document.getElementById('dsheet-email').checked;
    state.digital.screentime = document.getElementById('dsheet-screentime').checked;
    state.digital.enabled    = true;
    saveState();
    hideSheet();
    navigate('dashboard');
  });
}

function showLearnMore() {
  showSheet(`
    <div class="sheet-handle"></div>
    <button class="sheet-close" onclick="App.hideSheet()">×</button>
    <div class="sheet-title">How Manas Works</div>
    <div style="display:flex;flex-direction:column;gap:14px;font-size:14px;color:var(--ios-l1);">
      <div style="display:flex;gap:12px;align-items:flex-start;"><span style="font-size:22px">📊</span><div><strong>Passive monitoring</strong><br><span style="color:var(--ios-l2)">Reads heart rate, HRV, sleep, and activity from Apple Health. No effort from you.</span></div></div>
      <div style="display:flex;gap:12px;align-items:flex-start;"><span style="font-size:22px">🧠</span><div><strong>Personal baseline</strong><br><span style="color:var(--ios-l2)">Spends 7 days learning what's normal for you, so it detects changes — not averages.</span></div></div>
      <div style="display:flex;gap:12px;align-items:flex-start;"><span style="font-size:22px">🔒</span><div><strong>Private by design</strong><br><span style="color:var(--ios-l2)">All analysis runs on your iPhone. Raw data never leaves your device.</span></div></div>
      <div style="display:flex;gap:12px;align-items:flex-start;"><span style="font-size:22px">💙</span><div><strong>AI companion</strong><br><span style="color:var(--ios-l2)">6 specialist personas ready to listen, guide, and support — online or offline.</span></div></div>
    </div>
    <button class="btn btn-primary" style="margin-top:24px;" onclick="App.hideSheet()">Got it</button>
  `);
}

/* ═══════════════════════════════════════
   REFRESH BIOMETRICS
═══════════════════════════════════════ */
function refreshBiometrics() {
  const btn = document.getElementById('refresh-btn');
  if (btn) btn.style.opacity = '0.4';
  state.bio.hr   = Math.round(65 + Math.random() * 25);
  state.bio.hrv  = Math.round(35 + Math.random() * 35);
  state.bio.sleep = Math.round((5.5 + Math.random() * 3) * 10) / 10;
  state.bio.steps = Math.round(2000 + Math.random() * 8000);
  setTimeout(() => navigate('dashboard'), 600);
}

/* ═══════════════════════════════════════
   CLOCK
═══════════════════════════════════════ */
function updateClock() {
  const now = new Date();
  const h = now.getHours();
  const m = now.getMinutes().toString().padStart(2, '0');
  const el = document.getElementById('clock');
  if (el) el.textContent = `${h}:${m}`;
}

/* ═══════════════════════════════════════
   DEV TOOLS
═══════════════════════════════════════ */
const dev = {
  goto(screen) {
    if (['dashboard','companion','settings'].includes(screen)) {
      state.onboardingComplete = true;
    }
    navigate(screen);
  },
  setRisk(level) {
    state.riskLevel = level;
    state.wellnessScore = RISK[level].wellness;
    if (level === 'crisis') navigate('crisis');
    else if (state.screen === 'dashboard') navigate('dashboard');
    updateDevState();
  },
  refresh() { refreshBiometrics(); },
  resetOnboarding() {
    if (confirm('Reset onboarding?')) {
      state.onboardingComplete = false;
      state.contacts = [];
      state.messages = [];
      state.digital.enabled = false;
      localStorage.removeItem('manas_proto_state');
      navigate('welcome');
    }
  },
};

function updateDevState() {
  const el = document.getElementById('dev-state');
  if (!el) return;
  el.textContent =
    `screen: ${state.screen}\nrisk: ${state.riskLevel}\nwellness: ${state.wellnessScore}\n` +
    `contacts: ${state.contacts.length}\npersona: ${state.persona}\n` +
    `onboarded: ${state.onboardingComplete}\ndigital: ${state.digital.enabled ? 'on' : 'off'}`;
}

/* ═══════════════════════════════════════
   TAB BAR EVENTS
═══════════════════════════════════════ */
function bindTabBar() {
  document.querySelectorAll('.tab').forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
  });
}

/* ═══════════════════════════════════════
   INIT
═══════════════════════════════════════ */
function init() {
  loadState();
  bindTabBar();
  updateClock();
  setInterval(updateClock, 10000);

  const startScreen = state.onboardingComplete ? 'dashboard' : 'welcome';
  navigate(startScreen);
}

init();

/* ═══════════════════════════════════════
   PUBLIC API
═══════════════════════════════════════ */
return { dev, hideSheet, showLearnMore };

})();
