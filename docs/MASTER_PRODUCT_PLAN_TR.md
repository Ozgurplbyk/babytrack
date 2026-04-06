# BabyTrack Master Product Plan (TR-first, Global-ready)

## 1) Product Core

Goal: 0-18 yas cocuk sagligi + gelisim + hatira takibini tek uygulamada toplamak.

Core differentiation:

1. Country-aware health engine (TR/US/UK/DE).
2. Automatic vaccine schedule update pipeline (official authority sources).
3. Offline-first architecture.
4. AI assistant with source-linked guidance (not diagnosis).
5. Unified health + memory timeline.

## 2) Main Modules

1. Child Profiles (multi-child, twin mode, role-based caregivers).
2. Daily Tracking (feeding, breastfeeding left/right, bottle, sleep, diaper, symptoms).
3. Health Records (vaccines, checkups, labs, chronic conditions, meds, allergies).
4. Growth and Development (percentiles, milestones, tasks).
5. Memory Journal (first smile, first step, photo/video/audio notes).
6. Appointments and reminders (doctor, vaccine, medication).
7. Doctor Sharing (link + PDF + FHIR export).
8. Emergency card (critical info, allergy flags, care plans).

## 3) Mandatory Health Features

1. Vaccine engine:
   - Country + age + prior doses -> due/upcoming/overdue/catch-up.
   - Versioned schedule packages.
   - On-device fallback package for offline mode.
2. Triage:
   - Red/yellow/green flow based on symptoms + age.
   - Red flag -> emergency guidance.
3. Lab trends:
   - Ferritin, Vitamin D, lipid panel, CBC, custom tests.
4. Chronic care:
   - Asthma, allergy, epilepsy templates.
   - Attack journal + trigger analysis.

## 4) Memory and Engagement

1. Smart timeline with age-aware filters.
2. Firsts templates (first smile, first tooth, first word).
3. Auto monthly story (AI summary from user records).
4. Same day last year reminder.
5. Annual memory book export (PDF, print-ready).

## 5) Technical Architecture (High-level)

1. iOS first:
   - SwiftUI
   - Local DB (SQLite/CoreData)
   - Background sync queue
2. Backend:
   - Auth, sync, source packages, share links, subscriptions
   - Rule package delivery and rollback
3. Data model:
   - Event-based (each log = immutable event + optional update event)
4. Security:
   - Encryption at rest and in transit
   - Audit log for sensitive actions
   - Fine-grained visibility per record

## 6) Compliance and Safety

1. Apple medical-safe positioning:
   - Informational and tracking support only.
   - No diagnostic claim.
2. Source transparency:
   - Show authority + version + effective date for each rule.
3. Child data governance:
   - Consent, deletion flows, export controls.

## 7) Delivery Phases

### P0 (MVP)

1. Profiles + daily tracking + memory journal.
2. Vaccine records + schedule reminders.
3. Checkups + growth chart + lab logs.
4. Offline-first sync.
5. Baseline premium paywall.

### P1

1. Triage + chronic care templates.
2. Doctor sharing link + advanced PDF.
3. Country-specific schedule engine with signed updates.
4. AI summaries and weekly plan cards.

### P2

1. FHIR package export.
2. Device integrations.
3. Advanced analytics and trigger prediction.
4. Web doctor dashboard.

