# Cycle intelligence

Nyla's cycle engine is designed to be useful without pretending a phone calendar can directly observe ovarian hormones.

The engine separates three kinds of information:

1. **Observed** — a recorded period start/end or an explicit daily log.
2. **Personally inferred** — estimates learned from the person's own completed-cycle history and repeated daily observations.
3. **Biologically plausible context** — population evidence used only as a broad prior when direct evidence is unavailable.

The UI should preserve that distinction. An estimate may be helpful; it must not be styled or worded as a measurement.

## Prediction model

Period prediction uses recorded period starts only. Spotting is not promoted to a period start.

The predictor:

- preserves all user history;
- ignores intervals touching a period the user explicitly excluded from prediction;
- uses recent completed intervals, with strong statistical outliers filtered only when enough history exists;
- recognizes a long interval as probable missed tracking only when a personal rhythm is already established and the interval is close to a clean 2x/3x multiple of that rhythm;
- estimates the next interval with a recency-weighted personal mean;
- calibrates uncertainty from both robust cycle variability and rolling historical forecast error;
- keeps a finite-history uncertainty floor so a few identical cycles never look artificially exact;
- always shows a date range rather than treating one date as certain.

A suspected missed-tracking interval is never removed from the database or rewritten. It simply does not steer the current forecast.

### Why tracking adherence matters

Large self-tracking datasets show that missed logging can materially affect menstrual-cycle prediction. The prediction model therefore treats obvious tracking gaps separately from ordinary biological variability, but only under conservative personal-history conditions.

Relevant evidence:

- Li K, Urteaga I, Wiggins CH, et al. *A predictive model for next cycle start date that accounts for adherence in menstrual self-tracking.* Journal of the American Medical Informatics Association. 2022. https://pubmed.ncbi.nlm.nih.gov/35986610/
- Bull JR, Rowland SP, Scherwitzl EB, et al. *Real-world menstrual cycle characteristics of more than 600,000 menstrual cycles.* npj Digital Medicine. 2019. https://pmc.ncbi.nlm.nih.gov/articles/PMC6710244/

## Phase model

Nyla presents everyday phase context as:

- **Menstruation** — bleeding context, overlapping biologically with the early follicular phase.
- **Follicular phase** — before the broad estimated peri-ovulatory window.
- **Peri-ovulatory · estimated** — a deliberately broad window, never a single ovulation day.
- **Luteal phase · estimated** — likely post-ovulatory context after the broad window and before the next predicted period.
- **Uncertain** — shown when the evidence is not strong enough to justify a phase label, including when a predicted period range has clearly passed.

### Why there are not four equal calendar quarters

The follicular phase and ovulation timing account for much of menstrual-cycle variability. The luteal phase is less variable on average, but it is not a fixed 14 days. A textbook "day 14" rule is therefore inappropriate for individual phase placement.

Nyla centers a **broad** peri-ovulatory estimate approximately 13 days before the personally predicted next period, using a ~12-day luteal duration as a population prior. Prediction uncertainty widens the window. The result is contextual education, not an ovulation measurement.

Relevant evidence:

- Bull JR, Rowland SP, Scherwitzl EB, et al. *Real-world menstrual cycle characteristics of more than 600,000 menstrual cycles.* npj Digital Medicine. 2019. https://pmc.ncbi.nlm.nih.gov/articles/PMC6710244/
- Fehring RJ, Schneider M, Raviele K. *Variability in the phases of the menstrual cycle.* Journal of Obstetric, Gynecologic & Neonatal Nursing. 2006. https://pubmed.ncbi.nlm.nih.gov/16700687/
- Najmabadi S, Schliep KC, Simonsen SE, et al. *Menstrual bleeding, cycle length, and follicular and luteal phase lengths in women without known subfertility: a pooled analysis of three cohorts.* Paediatric and Perinatal Epidemiology. 2020. https://pubmed.ncbi.nlm.nih.gov/31444894/
- Soumpasis I, Grace B, Johnson S. *Real-life insights on menstrual cycles and ovulation using big data.* Human Reproduction Open / related app cohort evidence. https://pubmed.ncbi.nlm.nih.gov/31272722/

## Cervical-fluid evidence

Watery or stretchy cervical fluid is treated as an **estrogenic mucus signal**. When it appears near the broad calendar-derived peri-ovulatory window, Nyla may raise the evidence level from estimated to supported.

It does **not**:

- identify an exact ovulation day;
- shrink the window into a precise date;
- create a contraceptive or conception recommendation;
- override a recorded period.

Several days of estrogenic-quality mucus can occur around the ovulatory process, and self-observation is inherently noisy.

Relevant evidence:

- Stanford JB, White GL, Hatasaka H. *Cervical mucus patterns and the fertile window in women without known subfertility.* Human Reproduction. 2021. https://pubmed.ncbi.nlm.nih.gov/33990841/
- Fehring RJ. Cervical-mucus and ovulation-marker validation literature. The engine uses mucus only as supportive context, never as proof.

## Personal-pattern intelligence

Nyla's strongest experience guidance comes from the person's own prospective logs.

Patterns can be learned in five broad regions:

- first days of menstruation;
- early follicular days;
- broad retrospective peri-ovulatory region;
- mid-luteal days;
- the four days before the next recorded period.

Eligible features include pain symptoms, energy, sleep, appetite/cravings, cervical fluid, digestion, heavy flow, mood selections and skin observations.

A pattern is surfaced only when:

- at least four adequately observed cycles exist;
- enough days were explicitly logged within each counted window;
- the feature appeared in at least three cycles;
- occurrence is at least 65% of adequately observed cycles.

**Missing data is unknown.** A day with no log never means the symptom was absent.

For multi-choice logs such as mood and skin, explicit absences are inferred only on days where the person saved at least one option in that group. A completely unlogged day remains unknown.

### Why prospective logs matter

Premenstrual disorders and recurring menstrual symptoms are best evaluated with prospective daily ratings across cycles. Retrospective memory alone can overstate or blur timing.

Relevant evidence:

- Freeman EW, Halbreich U, Grubb GS, et al. *An overview of four studies of a continuous oral contraceptive (levonorgestrel 90 mcg/ethinyl estradiol 20 mcg) on premenstrual dysphoric disorder and premenstrual syndrome.* Daily-rating literature and prospective symptom methodology.
- Yonkers KA, O'Brien PMS, Eriksson E. *Premenstrual syndrome.* Lancet. 2008; prospective daily symptom assessment is central to reliable timing.
- Freeman EW, et al. *Core symptoms that discriminate premenstrual syndrome.* Journal of Women's Health. 2011. https://pubmed.ncbi.nlm.nih.gov/21128818/

## "You might notice" contract

Population evidence can suggest experiences worth explaining, but Nyla must never tell someone what their personality, productivity, libido or mood *should* be because of a phase.

Examples of appropriate population context:

- cramps and some gastrointestinal symptoms around menstruation;
- cervical-fluid changes as estrogen rises before ovulation;
- breast tenderness, bloating, appetite/sleep changes or mood symptoms for some people in later luteal days.

Examples of inappropriate deterministic claims:

- "you will feel focused in the follicular phase";
- "you are most confident at ovulation";
- "the luteal phase makes you emotional";
- universal energy/productivity scripts.

Hormone-verified and prospective studies do not show one universal phase-linked mood or well-being pattern in healthy people. Nyla therefore gives a person's repeated logs precedence over generic experience cues.

Relevant evidence:

- Romans SE, Clarkson R, Gill T, et al. *Mood and the menstrual cycle: a review of prospective data studies.* Psychotherapy and Psychosomatics. https://pubmed.ncbi.nlm.nih.gov/23147261/
- Recent hormone-verified longitudinal work: *Associations between menstrual cycle phases and sexuality, well-being and mood in young healthy women.* https://pubmed.ncbi.nlm.nih.gov/40976232/
- Van Goozen SHM, et al. *Mood changes and physical complaints during the normal menstrual cycle in healthy young women.* https://pubmed.ncbi.nlm.nih.gov/2359810/

## Menstrual pain and prostaglandins

The educational layer may explain that prostaglandins support uterine contractions and are associated with primary dysmenorrhea. This is a mechanism explanation, not a diagnosis for any individual person's pain.

Relevant evidence:

- Dawood MY, et al. *Relief of dysmenorrhea with ibuprofen: effect on prostaglandin levels in menstrual fluid.* American Journal of Obstetrics and Gynecology. https://pubmed.ncbi.nlm.nih.gov/474640/
- Endotext. *The Normal Menstrual Cycle and the Control of Ovulation.* https://www.ncbi.nlm.nih.gov/books/NBK279054/

## Privacy and performance

All cycle intelligence runs locally in pure Dart over the existing local database materialization.

There is:

- no remote health inference;
- no runtime AI request;
- no new analytics stream;
- no new health-data field required for the phase model;
- no background network dependency for prediction.

The richer engine derives more value from data Nyla already stores. Sync remains an encrypted transport mechanism and does not become an intelligence service.

## Review rule

Any future change that makes a biological claim should answer four questions before merge:

1. Is the input observed, personally inferred, or population-derived?
2. Does the UI communicate that evidence level?
3. Does a primary/authoritative source support the mechanism or timing claim?
4. Could the wording be mistaken for a diagnosis, exact ovulation measurement, or deterministic phase stereotype?

If the fourth answer is yes, the wording or feature needs to be redesigned.
