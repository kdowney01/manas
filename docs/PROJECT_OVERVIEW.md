# MANAS — Project Overview

> *"Every mind deserves care, because silence should never be a sentence."*

## What Is Manas

MANAS (Multimodal AI for Awareness, Neurocognitive Analysis & Support) is an AI-driven, always-on mental health companion that proactively detects risk of mental health crises **before** they occur — without requiring self-disclosure from the user.

It is the MIT CTO Program (Cohort Group 2) Impact Project, being developed as a real product.

## The Problem

- 1 in 8 people globally live with a mental health condition
- 50% of conditions begin by age 14; 75% by age 24 — but detection is delayed by years
- Existing apps are reactive: they wait for the user to recognize and report distress
- 80% of mental health app users quit within 30 days
- Only 1 mental health professional per 100,000 people globally

## The Solution

Manas listens passively and continuously across multiple signal streams — facial expression, biometrics, speech, behavior, and app usage — to detect early warning signs of negative mental health trajectories and intervene before crisis escalates.

**Four core pillars:**
1. **Early Detection** — 6–12 months sooner than current clinical pathways
2. **Always-On** — passive monitoring, no burden on the user
3. **Privacy First** — on-device inference, federated learning, differential privacy
4. **Inclusive** — works across cultures, languages, underserved populations

## Team

| Name | Role |
|------|------|
| Daniel Gumucio | Founder & CEO |
| Sunita Gogineni | VP & Head of IT |
| Blair Day | SVP Engineering & IT |
| Kyle Downey | VP, Engineering |
| Kinshuk Dutta | Director, AI Product Management |

## Target Impact (FOM: t0 → t1)

| Metric | Current (t0) | Target (t1) |
|--------|-------------|-------------|
| Early detection lead-time | 0 | 6–12 months sooner |
| Underserved reach | 1.0× | 1.3–1.4× |
| User retention (90-day) | 1.0× | 2.0× |
| Relapse reduction | baseline | −25% |
| Crisis detection accuracy | ~75% | ≥95% |
| Alert latency | ≥120s | <30s |

## R&D Portfolio (5 Projects)

| Project | Deliverable | Duration | Budget | Risk |
|---------|------------|----------|--------|------|
| P1: Signal discovery + PRD | PRD + ethics/regulatory | 3 mo | $700K | Low |
| P2: MVP platform + pilot app | Backend + mobile + analytics | 5 mo | $3.5M | Med |
| P3: Multimodal detection v1 | Text/speech models + eval | 6 mo | $4M | Med |
| P4: Privacy + governance | On-device + federated sandbox | 6 mo | $2.5M | High |
| P5: Pilot programs | Partner pilots + KPI dashboards | 6 mo | $2.5M | Med |

**Total: $15.2M (base $13.2M + 15% mgmt reserve)**

## This Repository

This repo contains the **iOS application** — the mobile-first pilot app for P2. It connects to the existing MAANAS AI engine backend and surfaces real-time mental health monitoring to users in a privacy-first, always-on mobile experience.

See [ARCHITECTURE.md](architecture/ARCHITECTURE.md) for technical design.
