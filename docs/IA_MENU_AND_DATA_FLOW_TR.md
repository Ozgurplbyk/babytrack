# IA, Menu, and Fast Data Entry Plan

## 1) Bottom Navigation

1. `Bugun`
2. `Zaman Tuneli`
3. `+ Ekle`
4. `Saglik`
5. `Aile`

## 2) Page Breakdown

### Bugun

1. Next critical actions (vaccine, appointment, meds).
2. Daily progress widgets:
   - sleep total
   - feeding count
   - diaper count
   - medication adherence
3. AI daily summary card.

### Zaman Tuneli

1. Unified health + memory events.
2. Filters:
   - child
   - date range
   - age window (example: 4 months 12 days)
   - event type
   - visibility level

### + Ekle (Fast logger)

Quick tiles:

1. Breastfeed Left
2. Breastfeed Right
3. Bottle
4. Pumping
5. Diaper Pee
6. Diaper Poop
7. Sleep Start/Stop
8. Fever
9. Symptom
10. Medication dose
11. Memory note (photo/video/audio/text)
12. Checkup note

### Saglik

1. Vaccine
2. Checkups
3. Growth charts
4. Labs
5. Chronic care plans
6. Triage
7. Medications and allergies
8. Documents
9. School/travel package

### Aile

1. Child profiles
2. Caregiver roles
3. Data visibility settings
4. Sharing and exports
5. Subscription and billing

## 3) Event Taxonomy (Core)

### Feeding

1. `breastfeeding_event`
   - side: left/right/both
   - start_time
   - end_time
   - notes
2. `bottle_event`
   - milk_type (breastmilk/formula/water)
   - volume_ml
   - brand_optional
3. `pumping_event`
   - side
   - volume_ml
   - duration_min

### Diaper

1. `diaper_event`
   - type (pee/poop/mixed)
   - stool_color
   - stool_texture
   - notes

### Sleep

1. `sleep_event`
   - segment (day/night)
   - start_time
   - end_time
   - awakenings

### Symptom and triage

1. `symptom_event`
   - symptom_code
   - severity
   - fever_c_optional
   - duration
   - triage_output

### Clinical

1. `vaccine_event`
2. `checkup_event`
3. `lab_event`
4. `chronic_event`
5. `medication_event`
6. `allergy_event`

### Memory

1. `memory_event`
   - media_type (photo/video/audio/text)
   - title
   - tag_list
   - age_at_event

## 4) Permissions

Per-event visibility:

1. family
2. parents_only
3. private

