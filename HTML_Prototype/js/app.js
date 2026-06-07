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
  bio: { hr: 72, hrv: 48, sleep: 6.1, steps: 6421 },
  riskLevel: 'low',   // low | moderate | high | crisis
  scoreMethod: 'lowest',   // average | physio | lowest

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
      scoreMethod: state.scoreMethod,
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

// Map a 0–100 score onto a risk band (drives card color + label)
function riskFromScore(s) {
  if (s >= 75) return 'low';
  if (s >= 55) return 'moderate';
  if (s >= 35) return 'high';
  return 'crisis';
}

// How the Overall score combines the section scores (user-selectable)
const SCORE_METHODS = {
  average: { label: 'Equal average',     blurb: 'Your Physio and Digital scores, averaged equally.' },
  physio:  { label: 'Physio-weighted',   blurb: 'Weighted 60% Physio, 40% Digital.' },
  lowest:  { label: 'Lowest pulls down', blurb: 'Weighted toward your weaker domain, so one low area isn’t masked.' },
};

// Dev preset signal bundles per risk band — keeps scores/badges cohesive
const RISK_PRESETS = {
  low:      { bio: { hr: 68,  hrv: 58, sleep: 7.6, steps: 9200 }, digital: { screenTimeHrs: 4.2,  socialMin: 85,  msgTone: 'Positive',   emailTone: 'Positive' } },
  moderate: { bio: { hr: 74,  hrv: 42, sleep: 6.4, steps: 5600 }, digital: { screenTimeHrs: 6.4,  socialMin: 150, msgTone: 'Neutral',    emailTone: 'Neutral'  } },
  high:     { bio: { hr: 92,  hrv: 28, sleep: 5.1, steps: 2600 }, digital: { screenTimeHrs: 8.6,  socialMin: 240, msgTone: 'Tense',      emailTone: 'Negative' } },
  crisis:   { bio: { hr: 104, hrv: 19, sleep: 3.8, steps: 900  }, digital: { screenTimeHrs: 11.2, socialMin: 320, msgTone: 'Withdrawn',  emailTone: 'Negative' } },
};

const PHYSIO_TIPS = {
  'Heart Rate': 'Resting HR is outside your typical band — hydration, caffeine, or stress can contribute.',
  'HRV':        'Lower HRV can signal accumulated stress or under-recovery. Prioritize rest today.',
  'Sleep':      'You slept less than your baseline. Aim for a consistent wind-down tonight.',
  'Steps':      'Activity dipped below your usual level. A short walk can help reset.',
};
const DIGITAL_TIPS = {
  'Screen Time':  'Screen time is above your typical range — consider a deliberate break.',
  'Social Media': 'Social use is elevated. Notice how it’s affecting your mood.',
  'Message Tone': 'Your messaging language trended more negative than usual.',
  'Email Tone':   'Email language trended tense or negative recently.',
};

// Overall score — combines Physio + Digital per the selected method
function overallScore() {
  const p = physioScore();
  if (!state.digital.enabled) return p;
  const d = digitalScore(digitalMetrics());
  switch (state.scoreMethod) {
    case 'average': return Math.round((p + d) / 2);
    case 'physio':  return Math.round(p * 0.6 + d * 0.4);
    case 'lowest':
    default: {
      const lo = Math.min(p, d), hi = Math.max(p, d);
      return Math.round(lo * 0.65 + hi * 0.35);
    }
  }
}

// Short, tone-aware commentary — playful when high, gentler when low
function overallCommentary(score) {
  if (score >= 85) return "You're absolutely glowing today — whatever you're doing, keep it up! ✨";
  if (score >= 75) return "Feeling good! Mind and body are in a nice rhythm right now. 😊";
  if (score >= 55) return "A bit of a mixed bag today — go easy on yourself, you're doing fine. 💛";
  if (score >= 35) return "Things feel heavier than usual. Small steps count, and you've got this. 🌱";
  return "You're carrying a lot right now. Be gentle with yourself — you're not alone in this. 💙";
}
function physioCommentary(score) {
  if (score >= 85) return "Your body's running like a dream — well rested and recharged! 💪";
  if (score >= 75) return "Nice and steady — heart, sleep, and movement are all on your side. 😊";
  if (score >= 55) return "Your body's asking for a little extra care today. Hydrate and breathe. 💛";
  if (score >= 35) return "Running low on reserves. Rest counts too — be kind to your body. 🌱";
  return "Your body's under real strain right now. Please slow down and lean on support. 💙";
}
function digitalCommentary(score) {
  if (score >= 85) return "Your digital habits are in a great place — balanced and breezy. 🌿";
  if (score >= 75) return "Nice balance online today — screen and social habits look healthy. 😊";
  if (score >= 55) return "Things are creeping up a little online. A short screen break could help. 💛";
  if (score >= 35) return "Screens and feeds are taking a toll. A little unplugging goes a long way. 🌱";
  return "Your digital world feels heavy right now. You deserve a real break — and real support. 💙";
}

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

  // Consistent app nav bar (logo left, hamburger right) on all post-onboarding screens
  const nb = navBarEl();
  if (APP_SCREENS.includes(screenId)) {
    nb.classList.remove('hidden', 'large-title');
    nb.classList.add('app-nav');
    nb.innerHTML = appNavBar();
    document.getElementById('nav-home')?.addEventListener('click', () => switchTab('dashboard'));
    document.getElementById('menu-btn')?.addEventListener('click', openMenu);
  } else {
    nb.innerHTML = '';
    nb.classList.add('hidden');
    nb.classList.remove('large-title', 'app-nav');
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

  // Lock-screen mode: wallpaper fills the whole phone (behind status bar)
  $('phone')?.classList.toggle('lock-mode', screenId === 'notification');

  bindScreenEvents(screenId);
  updateDevState();
  saveState();
}

// Screens that carry the consistent app nav (everything after onboarding,
// excluding the crisis takeover and the lock-screen notification)
const APP_SCREENS = ['dashboard', 'companion', 'settings', 'overall-detail', 'physio-detail', 'digital-detail', 'privacy'];

function appNavBar() {
  return `
    <img src="assets/manas_logo.png" class="nav-logo" alt="manas" id="nav-home"/>
    <button class="nav-menu-btn" id="menu-btn" aria-label="Menu">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round">
        <line x1="3" y1="6"  x2="21" y2="6"/>
        <line x1="3" y1="12" x2="21" y2="12"/>
        <line x1="3" y1="18" x2="21" y2="18"/>
      </svg>
    </button>`;
}

function switchTab(tab) {
  navigate(tab);
}

/* ═══════════════════════════════════════
   HAMBURGER MENU (side drawer)
═══════════════════════════════════════ */
const MENU_LINKS = [
  { dest: 'dashboard',      label: 'Today' },
  { dest: 'overall-detail', label: 'Overall Wellbeing' },
  { dest: 'physio-detail',  label: 'Physio Wellbeing' },
  { dest: 'digital-detail', label: 'Digital Wellbeing' },
  { dest: 'companion',      label: 'Companion' },
  { dest: 'settings',       label: 'Settings' },
  { divider: true },
  { dest: 'crisis',  icon: '⚠️', label: 'Get Help Now', cls: 'menu-link-crisis' },
  { dest: 'privacy', label: 'Privacy' },
  { dest: 'signout', label: 'Sign Out', cls: 'menu-link-muted' },
];

function buildMenu() {
  return `
    <div class="menu-head">
      <img src="assets/manas_logo.png" class="menu-logo" alt="manas"/>
      <button class="menu-close" id="menu-close" aria-label="Close">×</button>
    </div>
    <div class="menu-links">
      ${MENU_LINKS.map(l => l.divider
        ? '<div class="menu-divider"></div>'
        : `<button class="menu-link ${l.cls || ''}" data-nav="${l.dest}">
             ${l.icon ? `<span class="menu-link-icon">${l.icon}</span>` : ''}<span>${l.label}</span>
           </button>`).join('')}
    </div>`;
}

function openMenu() {
  const overlay = $('menu-overlay'), drawer = $('menu-drawer');
  drawer.innerHTML = buildMenu();
  overlay.classList.remove('hidden');
  void drawer.offsetWidth;
  drawer.classList.add('open');
  overlay.onclick = closeMenu;
  document.getElementById('menu-close')?.addEventListener('click', closeMenu);
  drawer.querySelectorAll('[data-nav]').forEach(el =>
    el.addEventListener('click', () => handleMenuNav(el.dataset.nav)));
}
function closeMenu() {
  $('menu-drawer').classList.remove('open');
  $('menu-overlay').classList.add('hidden');
}
function handleMenuNav(dest) {
  closeMenu();
  if (dest === 'signout') {
    state.onboardingComplete = false;
    state.messages = [];
    saveState();
    navigate('welcome');
  } else if (['dashboard', 'companion', 'settings'].includes(dest)) {
    switchTab(dest);
  } else {
    navigate(dest);
  }
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
          <button class="btn btn-ghost" id="ec-pick">Choose from Contacts</button>
          <div class="ec-or">or enter manually</div>
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

  /* ── Dashboard (Today) — three score cards ── */
  'dashboard': () => `
    <div class="dashboard screen-animate">
      <div>
        <div class="greeting-hi">Good morning, Kyle 👋</div>
        <div class="greeting-date">${formatDate()} · Updated just now</div>
      </div>

      ${overallCard()}

      <div class="card-pair">
        ${physioCard()}
        ${digitalCard()}
      </div>
    </div>`,

  /* ── Overall Wellbeing — detail ── */
  'overall-detail': () => {
    const score = overallScore();
    const risk  = RISK[riskFromScore(score)];
    const p = physioScore();
    const dEnabled = state.digital.enabled;
    const d = dEnabled ? digitalScore(digitalMetrics()) : null;
    return `
    <div class="detail-screen">
      ${ringCard('Overall Wellbeing', score, risk, overallCommentary(score), 'overall-card')}

      <div class="section-hd" style="padding-left:2px;">Breakdown</div>
      <div class="list-section">
        ${breakdownRow('physio-detail', 'Physio Wellbeing', '❤️', p)}
        ${dEnabled
          ? breakdownRow('digital-detail', 'Digital Wellbeing', '📲', d)
          : `<div class="list-row" id="enable-digital-row" style="cursor:pointer;">
               <div class="list-row-icon">📲</div>
               <div class="list-row-content"><div class="list-row-label">Digital Wellbeing</div><div class="list-row-detail">Not set up — tap to enable</div></div>
               <div class="list-row-trail">+</div>
             </div>`}
      </div>

      <div class="section-hd" style="padding-left:2px;">Daily Insight</div>
      <div class="insight-card" id="insight-tap">
        <div class="insight-header">
          <span style="font-size:14px">💡</span>
          <span class="insight-label">Daily Insight</span>
        </div>
        <div class="insight-text">Your HRV is 18% above your 7-day average. Combined with consistent sleep, you're in a positive recovery window. <span style="color:var(--indigo);font-weight:600">Talk to your companion →</span></div>
      </div>

      <div>
        <div class="section-hd" style="padding-left:2px;">Recent Alerts</div>
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

  /* ── Physio Wellbeing — detail ── */
  'physio-detail': () => {
    const score = physioScore();
    const risk  = RISK[riskFromScore(score)];
    const m = physioMetrics();
    const flags = m.filter(x => !x.good);
    return `
    <div class="detail-screen">
      ${ringCard('Physio Wellbeing', score, risk, physioCommentary(score), 'accent-physio')}
      <div class="section-hd" style="padding-left:2px;">Signals</div>
      <div class="bio-grid">${m.map(signalTile).join('')}</div>
      ${flags.length ? flaggedBlock(flags, PHYSIO_TIPS) : okBlock()}
      <div class="detail-note">Scores compare today's readings to your personal 7-day baseline. All processing happens on-device.</div>
    </div>`;
  },

  /* ── Digital Wellbeing — detail ── */
  'digital-detail': () => {
    if (!state.digital.enabled) {
      return `
      <div class="detail-screen">
        <div class="detail-empty">
          <div style="font-size:40px;margin-bottom:8px;">📲</div>
          <div class="flag-title" style="margin-bottom:4px;">Digital signals are off</div>
          <div class="flag-tip" style="margin-bottom:16px;">Turn them on to track screen time, social, and message tone.</div>
          <button class="btn btn-primary" id="enable-digital-btn">Enable Digital Signals</button>
        </div>
      </div>`;
    }
    const score = digitalScore(digitalMetrics());
    const risk  = RISK[riskFromScore(score)];
    const m = digitalMetrics();
    const flags = m.filter(x => !x.good);
    return `
    <div class="detail-screen">
      ${ringCard('Digital Wellbeing', score, risk, digitalCommentary(score), 'accent-digital')}
      <div class="section-hd" style="padding-left:2px;">Signals</div>
      <div class="bio-grid">${m.map(signalTile).join('')}</div>
      ${flags.length ? flaggedBlock(flags, DIGITAL_TIPS) : okBlock()}
      <div class="detail-note">📲 Tone is computed on-device from language patterns. Raw message &amp; email content is never stored or sent.</div>
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

      <!-- Wellbeing score -->
      <div class="section-hd">Wellbeing Score</div>
      <div class="list-section" style="margin:0 16px;">
        <div class="list-row" id="score-method-row" style="cursor:pointer;">
          <div class="list-row-icon">🧮</div>
          <div class="list-row-content">
            <div class="list-row-label">Overall score method</div>
            <div class="list-row-detail">How Physio &amp; Digital combine</div>
          </div>
          <div class="list-row-trail">${SCORE_METHODS[state.scoreMethod].label} ›</div>
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

  /* ── Lock-screen push notification ── */
  'notification': () => {
    const now = new Date();
    const h = now.getHours();
    const m = String(now.getMinutes()).padStart(2, '0');
    return `
    <div class="lock-screen">
      <div class="lock-time-wrap">
        <div class="lock-date">${formatDate()}</div>
        <div class="lock-clock">${h}:${m}</div>
      </div>
      <div class="lock-notifs">
        <div class="ios-notif" id="lock-notif">
          <img src="assets/manas_logo.png" class="ios-notif-icon" alt="Manas"/>
          <div class="ios-notif-body">
            <div class="ios-notif-top">
              <span class="ios-notif-app">Manas</span>
              <span class="ios-notif-time">now</span>
            </div>
            <div class="ios-notif-text">Hey, we've noticed you are on social media a lot lately. Are you doing ok? Take a break if you need to.</div>
          </div>
        </div>
      </div>
    </div>`;
  },

  /* ── Privacy ── */
  'privacy': () => `
    <div class="detail-screen">
      <div class="privacy-hero">
        <div class="privacy-hero-icon">🔒</div>
        <div class="privacy-hero-title">Your privacy, in plain English</div>
        <div class="privacy-hero-sub">Manas is designed to understand how you're doing — without collecting your private life. Here's exactly how.</div>
      </div>

      ${privacyItem('📱', 'Everything happens on your phone', "Your health data, facial signals, and digital habits are analyzed right on your device. Nothing is shipped off to a server to be processed somewhere else.")}
      ${privacyItem('🙈', 'We never see your raw data', "Manas doesn't store or send your actual heart rate, your messages, your emails, or any video of your face. It only works with the scores it calculates on-device.")}
      ${privacyItem('💬', 'Your words stay yours', "For texts and email, Manas reads only the overall emotional tone — never the words themselves. The content of your messages is never saved or transmitted.")}
      ${privacyItem('🔐', 'Locked down on device', "Anything sensitive we do keep — like your emergency contacts — lives in your iPhone's encrypted Keychain, never in a plain file or the cloud.")}
      ${privacyItem('📵', 'No ads, no tracking, no selling', "There are no advertising or analytics trackers in Manas. We don't profile you for marketing, and we never sell your data.")}
      ${privacyItem('🎚️', "You're in control", "You choose which signals to turn on, you can switch any of them off anytime, and you can export or delete everything Manas knows about you whenever you want.")}

      <div class="detail-note">Manas follows HIPAA-aligned safeguards. Before any data is ever shared with a connected health service, a formal agreement (a BAA) must be in place.</div>
    </div>`,
};

/* ═══════════════════════════════════════
   SCREEN HELPERS
═══════════════════════════════════════ */
function metricTile(icon, iconBg, val, label, trend, trendType, watch) {
  return `<div class="metric-tile">
    <div class="metric-icon-row">
      <div class="metric-ico-wrap">
        <div class="metric-ico" style="background:${iconBg}">${icon}</div>
        ${watch ? '<span class="metric-badge"></span>' : ''}
      </div>
      <div class="metric-trend trend-${trendType}">${trend}</div>
    </div>
    <div class="metric-val">${val}</div>
    <div class="metric-lbl">${label}</div>
  </div>`;
}

/* ── Scored signal sections (Physio Health / Digital Wellbeing) ── */
function scoreColor(score) {
  if (score >= 75) return 'var(--risk-low)';
  if (score >= 50) return 'var(--risk-mod)';
  if (score >= 30) return 'var(--risk-high)';
  return 'var(--risk-crisis)';
}

function signalTile(m) {
  return metricTile(m.icon, m.bg, m.val, m.label, m.good ? 'OK' : 'Watch', m.good ? 'up' : 'down', !m.good);
}

/* Physio Health — derived from biometrics */
function physioMetrics() {
  const b = state.bio;
  return [
    { icon: '❤️', bg: 'rgba(255,59,48,0.09)',  val: b.hr + ' BPM',            label: 'Heart Rate', good: b.hr >= 55 && b.hr <= 85 },
    { icon: '〰️', bg: 'rgba(173,108,173,0.09)', val: b.hrv + ' ms',           label: 'HRV',        good: b.hrv >= 40 },
    { icon: '🌙', bg: 'rgba(92,108,179,0.09)',  val: b.sleep + 'h',           label: 'Sleep',      good: b.sleep >= 7 },
    { icon: '🚶', bg: 'rgba(52,199,89,0.09)',   val: b.steps.toLocaleString(),label: 'Steps',      good: b.steps >= 5000 },
  ];
}
function physioScore() {
  const b = state.bio;
  const hr    = (b.hr >= 55 && b.hr <= 85) ? 100 : Math.max(0, 100 - Math.abs(b.hr - 70) * 3);
  const hrv   = Math.min(100, Math.round(b.hrv / 70 * 100));
  const sleep = Math.min(100, Math.round(b.sleep / 8 * 100));
  const steps = Math.min(100, Math.round(b.steps / 10000 * 100));
  return Math.round((hr + hrv + sleep + steps) / 4);
}

/* Digital Wellbeing — derived from behavioral signals */
const POSITIVE_TONES = ['Positive', 'Neutral', 'Calm', 'Warm', 'Steady'];
function digitalMetrics() {
  const d = state.digital, m = [];
  if (d.screentime) m.push({ icon: '⏱️', bg: 'rgba(92,108,179,0.09)',  val: d.screenTimeHrs + 'h', label: 'Screen Time',  good: d.screenTimeHrs <= 6 });
  if (d.social)     m.push({ icon: '📲', bg: 'rgba(173,108,173,0.09)', val: d.socialMin + 'm',     label: 'Social Media', good: d.socialMin <= 120 });
  if (d.messages)   m.push({ icon: '💬', bg: 'rgba(52,199,89,0.09)',   val: d.msgTone,             label: 'Message Tone', good: POSITIVE_TONES.includes(d.msgTone) });
  if (d.email)      m.push({ icon: '✉️', bg: 'rgba(255,179,151,0.18)', val: d.emailTone,           label: 'Email Tone',   good: POSITIVE_TONES.includes(d.emailTone) });
  return m;
}
function digitalScore(metrics) {
  if (!metrics.length) return 0;
  return Math.round(metrics.filter(m => m.good).length / metrics.length * 100);
}

/* ── Score ring + cards ── */
function ringSvg(score, color, size) {
  const circ = 326.7;
  const arc = Math.round((score / 100) * circ);
  const gap = circ - arc;
  const big = size >= 90;
  return `<svg width="${size}" height="${size}" viewBox="0 0 120 120">
    <circle cx="60" cy="60" r="52" fill="none" stroke="#E5E5EA" stroke-width="8"/>
    <circle cx="60" cy="60" r="52" fill="none" stroke="${color}" stroke-width="8"
      stroke-dasharray="${arc} ${gap}" stroke-linecap="round" class="ring-progress" transform="rotate(-90 60 60)"/>
    <text x="60" y="${big ? 54 : 68}" text-anchor="middle" font-family="Montserrat,sans-serif" font-weight="800" font-size="${big ? 26 : 24}" fill="#1C1C1E">${score}</text>
    ${big ? `<text x="60" y="70" text-anchor="middle" font-family="Montserrat,sans-serif" font-weight="600" font-size="9" fill="#AEAEB2" letter-spacing="1">OF 100</text>` : ''}
  </svg>`;
}

// Big ring card (Overall card + all three detail headers)
function ringCard(eyebrow, score, risk, detail, accentClass) {
  return `
    <div class="card ring-card ${accentClass || ''}">
      <div class="ring-eyebrow">${eyebrow}</div>
      <div class="ring-body">
        ${ringSvg(score, risk.color, 100)}
        <div class="ring-info">
          <div class="ring-status" style="background:${risk.bgColor};color:${risk.color}">
            <svg width="7" height="7"><circle cx="3.5" cy="3.5" r="3.5" fill="${risk.color}"/></svg>
            ${risk.label} Risk
          </div>
          <div class="ring-detail">${detail}</div>
        </div>
      </div>
    </div>`;
}

// Overall hero card on the Today tab (tappable)
function overallCard() {
  const score = overallScore();
  const risk  = RISK[riskFromScore(score)];
  const watch = physioMetrics().filter(m => !m.good).length +
                (state.digital.enabled ? digitalMetrics().filter(m => !m.good).length : 0);
  const detail = watch > 0
    ? `${watch} area${watch > 1 ? 's' : ''} need${watch > 1 ? '' : 's'} a closer look.`
    : 'All signals within your baseline range.';
  return `
    <div class="card ring-card overall-card" id="overall-card">
      <div class="ring-eyebrow">Overall Wellbeing</div>
      <div class="ring-body">
        ${ringSvg(score, risk.color, 100)}
        <div class="ring-info">
          <div class="ring-status" style="background:${risk.bgColor};color:${risk.color}">
            <svg width="7" height="7"><circle cx="3.5" cy="3.5" r="3.5" fill="${risk.color}"/></svg>
            ${risk.label} Risk
          </div>
          <div class="ring-detail">${detail}</div>
        </div>
        <div class="card-chevron">›</div>
      </div>
    </div>`;
}

// Compact section cards (Physio / Digital) — side by side
function miniCard(id, label, icon, accent, score, watch) {
  return `
    <div class="mini-card" id="${id}" style="border-top:3px solid ${accent}">
      <div class="mini-top">
        <div class="mini-eyebrow" style="color:${accent}">${icon} ${label}</div>
        ${watch > 0 ? `<span class="signal-badge">${watch}</span>` : ''}
      </div>
      <div class="mini-ring">${ringSvg(score, scoreColor(score), 70)}</div>
      <div class="mini-foot">View details ›</div>
    </div>`;
}
function physioCard() {
  const m = physioMetrics();
  return miniCard('physio-card', 'Physio', '❤️', 'var(--lavender)', physioScore(), m.filter(x => !x.good).length);
}
function digitalCard() {
  if (!state.digital.enabled) {
    return `
      <div class="mini-card mini-card-empty" id="digital-card" style="border-top:3px solid var(--lavender)">
        <div class="mini-top"><div class="mini-eyebrow" style="color:var(--lavender)">📲 Digital</div></div>
        <div class="mini-empty-plus">+</div>
        <div class="mini-foot">Set up ›</div>
      </div>`;
  }
  const m = digitalMetrics();
  return miniCard('digital-card', 'Digital', '📲', 'var(--lavender)', digitalScore(m), m.filter(x => !x.good).length);
}

// Breakdown row (Overall detail → section detail)
function breakdownRow(target, label, icon, score) {
  const c = scoreColor(score);
  return `
    <div class="list-row breakdown-row" data-detail="${target}" style="cursor:pointer;">
      <div class="list-row-icon">${icon}</div>
      <div class="list-row-content">
        <div class="list-row-label">${label}</div>
        <div class="bd-bar"><div class="bd-fill" style="width:${score}%;background:${c}"></div></div>
      </div>
      <div class="bd-score" style="color:${c}">${score}</div>
      <div class="list-row-trail">›</div>
    </div>`;
}

// Flagged-area callouts on a detail screen
function flaggedBlock(flags, tips) {
  return `
    <div class="section-hd" style="padding-left:2px;">Needs attention</div>
    <div style="display:flex;flex-direction:column;gap:8px;">
      ${flags.map(f => `
        <div class="flag-card">
          <div class="flag-icon">${f.icon}</div>
          <div>
            <div class="flag-title">${f.label} · ${f.val}</div>
            <div class="flag-tip">${tips[f.label] || 'Outside your usual range.'}</div>
          </div>
        </div>`).join('')}
    </div>`;
}
function okBlock() {
  return `
    <div class="ok-block">
      <span class="ok-check">✓</span>
      <div>
        <div class="flag-title">Everything looks healthy</div>
        <div class="flag-tip">All signals are within your personal baseline range.</div>
      </div>
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

function renderMsg(role, icon, text) {
  return `<div class="msg ${role}">
    ${role === 'ai' ? `<div class="msg-avatar">${icon}</div>` : ''}
    <div class="msg-bubble">${text}</div>
  </div>`;
}

function privacyItem(icon, title, body) {
  return `
    <div class="privacy-item">
      <div class="privacy-item-icon">${icon}</div>
      <div>
        <div class="privacy-item-title">${title}</div>
        <div class="privacy-item-body">${body}</div>
      </div>
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
      document.getElementById('ec-pick')?.addEventListener('click', () => {
        showContactPicker(c => {
          hideSheet();
          document.getElementById('ec-name').value = c.name;
          document.getElementById('ec-phone').value = c.phone;
          document.getElementById('ec-rel')?.focus();
        });
      });
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
      document.getElementById('overall-card')?.addEventListener('click', () => navigate('overall-detail'));
      document.getElementById('physio-card')?.addEventListener('click', () => navigate('physio-detail'));
      document.getElementById('digital-card')?.addEventListener('click', () => {
        if (state.digital.enabled) navigate('digital-detail');
        else showDigitalSheet();
      });
      break;

    case 'overall-detail':
      document.getElementById('insight-tap')?.addEventListener('click', () => switchTab('companion'));
      document.getElementById('enable-digital-row')?.addEventListener('click', showDigitalSheet);
      document.querySelectorAll('[data-detail]').forEach(el => {
        el.addEventListener('click', () => navigate(el.dataset.detail));
      });
      break;

    case 'digital-detail':
      document.getElementById('enable-digital-btn')?.addEventListener('click', showDigitalSheet);
      break;

    case 'notification':
      // Tapping the push notification opens the supportive companion (like unlocking into the app)
      document.getElementById('lock-notif')?.addEventListener('click', () => switchTab('companion'));
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
      document.getElementById('score-method-row')?.addEventListener('click', showScoreMethodSheet);
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

// Simulated iPhone address book (real app: CNContactPickerViewController)
const DEVICE_CONTACTS = [
  { name: 'Alex Rivera',   phone: '(555) 0142' },
  { name: 'Elena Vasquez', phone: '(555) 0314' },
  { name: 'Jordan Lee',    phone: '(555) 0188' },
  { name: 'Marcus Cole',   phone: '(555) 0299' },
  { name: 'Maya Patel',    phone: '(555) 0207' },
  { name: 'Priya Nair',    phone: '(555) 0261' },
  { name: 'Sam Brooks',    phone: '(555) 0233' },
  { name: 'Tom Becker',    phone: '(555) 0356' },
];

function initials(name) {
  return name.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase();
}

// Contact picker sheet — calls onPick(contact) with the chosen entry
function showContactPicker(onPick) {
  showSheet(`
    <div class="sheet-handle"></div>
    <button class="sheet-close" onclick="App.hideSheet()">×</button>
    <div class="sheet-title">Choose from Contacts</div>
    <div style="font-size:12px;color:var(--ios-l3);text-align:center;margin:-12px 0 14px;">Simulated — these would come from your iPhone Contacts.</div>
    <div class="contact-pick-list">
      ${DEVICE_CONTACTS.map((c, i) => `
        <button class="contact-pick-row" data-pick="${i}">
          <span class="contact-avatar">${initials(c.name)}</span>
          <span class="contact-pick-info">
            <span class="contact-pick-name">${c.name}</span>
            <span class="contact-pick-phone">${c.phone}</span>
          </span>
        </button>`).join('')}
    </div>
    <div class="sheet-cancel" onclick="App.hideSheet()">Cancel</div>
  `);
  document.querySelectorAll('[data-pick]').forEach(el =>
    el.addEventListener('click', () => onPick(DEVICE_CONTACTS[parseInt(el.dataset.pick)])));
}

function showAddContactSheet(prefill = {}) {
  showSheet(`
    <div class="sheet-handle"></div>
    <button class="sheet-close" onclick="App.hideSheet()">×</button>
    <div class="sheet-title">Add Emergency Contact</div>
    <button class="btn btn-ghost" id="s-pick" style="margin-bottom:14px;">Choose from Contacts</button>
    <input class="sheet-input" id="s-name" placeholder="Full name" value="${prefill.name || ''}">
    <input class="sheet-input" id="s-phone" placeholder="Phone number" type="tel" value="${prefill.phone || ''}">
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
  document.getElementById('s-pick')?.addEventListener('click', () => {
    showContactPicker(c => showAddContactSheet({ name: c.name, phone: c.phone }));
  });
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

function showScoreMethodSheet() {
  showSheet(`
    <div class="sheet-handle"></div>
    <button class="sheet-close" onclick="App.hideSheet()">×</button>
    <div class="sheet-title">Overall Score Method</div>
    <div style="font-size:13px;color:var(--ios-l2);line-height:1.5;margin:-8px 0 16px;text-align:center;">
      How your Physio and Digital scores combine into one Overall Wellbeing score.
    </div>
    <div class="persona-list">
      ${Object.entries(SCORE_METHODS).map(([k, v]) => `
        <div class="persona-list-item${state.scoreMethod === k ? ' active' : ''}" data-method="${k}">
          <div style="flex:1">
            <div class="persona-list-name">${v.label}</div>
            <div class="persona-list-desc">${v.blurb}</div>
          </div>
          ${state.scoreMethod === k ? '<div class="persona-list-check">✓</div>' : ''}
        </div>`).join('')}
    </div>
    <div class="sheet-cancel" onclick="App.hideSheet()">Done</div>
  `);
  document.querySelectorAll('[data-method]').forEach(el => {
    el.addEventListener('click', () => {
      state.scoreMethod = el.dataset.method;
      saveState();
      hideSheet();
      navigate(state.screen);
    });
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
    if (APP_SCREENS.includes(screen)) {
      state.onboardingComplete = true;
    }
    navigate(screen);
  },
  setRisk(level) {
    const preset = RISK_PRESETS[level];
    if (preset) {
      Object.assign(state.bio, preset.bio);
      if (state.digital.enabled) Object.assign(state.digital, preset.digital);
    }
    state.riskLevel = level;
    if (level === 'crisis') navigate('crisis');
    else if (['dashboard','overall-detail','physio-detail','digital-detail'].includes(state.screen)) navigate(state.screen);
    else navigate('dashboard');
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
    `screen: ${state.screen}\nrisk: ${state.riskLevel}\noverall: ${overallScore()}\n` +
    `physio: ${physioScore()}\ndigital: ${state.digital.enabled ? digitalScore(digitalMetrics()) : 'off'}\n` +
    `contacts: ${state.contacts.length}\npersona: ${state.persona}\n` +
    `onboarded: ${state.onboardingComplete}\nscore-method: ${state.scoreMethod}`;
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
