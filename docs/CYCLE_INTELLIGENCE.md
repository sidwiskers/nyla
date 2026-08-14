# Cycle intelligence

Nyla's cycle engine is designed to be useful without pretending a phone calendar can directly observe ovarian hormones.

The engine separates three kinds of information:

1. **Observed** — a recorded period start/end or an explicit daily log.
2. **Personally inferred** — estimates learned from the person's own completed-cycle history and repeated daily observations.
3. **Biologically plausible context** — population evidence used only as a broad prior when direct evidence is unavailable.

The UI must preserve that distinction. An estimate may be useful; it must not be styled or worded as a measurement.

## Scope

The phase model describes spontaneous menstrual-cycle physiology from menstrual history and self-observation. A calendar-only tracker cannot determine whether ovulation occurred, measure hormones, diagnose a condition, or know whether hormonal contraception, pregnancy/postpartum physiology, perimenopause, endocrine disease, medication or another factor has altered ovarian cycling unless the product explicitly has that information.

For that reason Nyla:

- never exposes an exact ovulation date or fertile window;
- visibly labels peri-ovulatory and luteal placement as estimated;
- widens or removes phase certainty when the person's timing is not sufficiently supported;
- treats the person's recorded observations as stronger evidence than a population stereotype;
- does not use phase labels for contraception or conception guidance.

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

The estimator is a product prediction model, not a clinically validated diagnostic model. Its job is to be transparent, conservative and personally calibrated.

### Why tracking adherence matters

Large self-tracking datasets show that missed logging can materially affect next-cycle prediction. The model therefore treats only obvious, high-confidence tracking gaps separately from ordinary biological variability.

Relevant evidence:

- Li K, Urteaga I, Shea A, Vitzthum VJ, Wiggins CH, Elhadad N. *A predictive model for next cycle start date that accounts for adherence in menstrual self-tracking.* Journal of the American Medical Informatics Association. 2022. https://pubmed.ncbi.nlm.nih.gov/34534312/
- Bull JR, Rowland SP, Scherwitzl EB, et al. *Real-world menstrual cycle characteristics of more than 600,000 menstrual cycles.* npj Digital Medicine. 2019. https://pmc.ncbi.nlm.nih.gov/articles/PMC6710244/

## Phase model

Nyla presents everyday phase context as:

- **Menstruation** — bleeding context, overlapping biologically with the early follicular phase.
- **Follicular phase** — before the broad estimated peri-ovulatory window.
- **Peri-ovulatory · estimated** — a deliberately broad window, never a single ovulation day.
- **Luteal phase · estimated** — likely post-ovulatory context after the broad window and before the next predicted period.
- **Uncertain** — shown when the evidence is not strong enough to justify a phase label, including when a predicted period range has clearly passed.

### Why there are not four equal calendar quarters

The follicular phase and timing of ovulation account for much of menstrual-cycle variability. The luteal phase is less variable on average, but it is not a fixed 14 days. A textbook "day 14" rule is therefore inappropriate for individual phase placement.

Nyla centers a **broad** peri-ovulatory estimate approximately 13 days before the personally predicted next period, using a roughly 12-day luteal duration as a population prior. Personal prediction uncertainty widens the window. The result is contextual education, not an ovulation measurement.

Relevant evidence:

- Bull JR, Rowland SP, Scherwitzl EB, et al. *Real-world menstrual cycle characteristics of more than 600,000 menstrual cycles.* npj Digital Medicine. 2019. https://pmc.ncbi.nlm.nih.gov/articles/PMC6710244/
- Fehring RJ, Schneider M, Raviele K. *Variability in the phases of the menstrual cycle.* Journal of Obstetric, Gynecologic & Neonatal Nursing. 2006. https://pubmed.ncbi.nlm.nih.gov/16700687/
- Najmabadi S, Schliep KC, Simonsen SE, et al. *Menstrual bleeding, cycle length, and follicular and luteal phase lengths in women without known subfertility: a pooled analysis of three cohorts.* Paediatric and Perinatal Epidemiology. 2020. https://pubmed.ncbi.nlm.nih.gov/31444894/
- Faust L, Bradley D, Landau E, et al. *Findings from a mobile application-based cohort are consistent with established knowledge of the menstrual cycle, fertile window, and conception.* Fertility and Sterility. 2019. https://pubmed.ncbi.nlm.nih.gov/31272722/

## Cervical-fluid evidence

Watery or stretchy cervical fluid is treated as an **estrogenic mucus signal**. When it appears near the broad calendar-derived peri-ovulatory window, Nyla may raise the evidence level from estimated to supported.

It does **not**:

- identify an exact ovulation day;
- shrink the window into a precise date;
- create a contraceptive or conception recommendation;
- override a recorded period.

Prospective cohorts show that several days of estrogenic-quality mucus are common and that the pattern varies substantially within the same person, so one watery day is not a biological timestamp.

Relevant evidence:

- Najmabadi S, Schliep KC, Simonsen SE, et al. *Cervical mucus patterns and the fertile window in women without known subfertility: a pooled analysis of three cohorts.* Human Reproduction. 2021. https://pubmed.ncbi.nlm.nih.gov/33990841/
- Faust L, Bradley D, Landau E, et al. *Findings from a mobile application-based cohort are consistent with established knowledge of the menstrual cycle, fertile window, and conception.* Fertility and Sterility. 2019. https://pubmed.ncbi.nlm.nih.gov/31272722/

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

Premenstrual and recurring cycle-related symptoms are much more defensibly timed with prospective daily observations than with retrospective memory.

Relevant evidence:

- Freeman EW, Halberstadt SM, Rickels K, Legler JM, Lin H, Sammel MD. *Core symptoms that discriminate premenstrual syndrome.* Journal of Women's Health. 2011. Prospective daily symptom ratings from 1,081 women were used to discriminate recurring premenstrual symptoms. https://pubmed.ncbi.nlm.nih.gov/21128818/
- Romans SE, Kreindler D, Asllani E, et al. *Mood and the menstrual cycle.* Psychotherapy and Psychosomatics. 2013. Daily mood and health data were collected prospectively across six months. https://pubmed.ncbi.nlm.nih.gov/23147261/

## "You might notice" contract

Population evidence can suggest experiences worth explaining, but Nyla must never tell someone what their personality, productivity, libido or mood *should* be because of a phase.

Appropriate population context includes:

- cramps and some gastrointestinal symptoms around menstruation;
- cervical-fluid changes as estrogen rises before ovulation;
- breast tenderness, bloating, appetite/sleep changes or mood symptoms for some people in later luteal days.

Inappropriate deterministic claims include:

- "you will feel focused in the follicular phase";
- "you are most confident at ovulation";
- "the luteal phase makes you emotional";
- universal energy/productivity scripts.

Prospective and hormone-verified studies do not show one universal phase-linked mood or well-being pattern in healthy people. Nyla therefore gives a person's repeated logs precedence over generic experience cues.

Relevant evidence:

- Romans SE, Kreindler D, Asllani E, et al. *Mood and the menstrual cycle.* Psychotherapy and Psychosomatics. 2013. https://pubmed.ncbi.nlm.nih.gov/23147261/
- *Associations between menstrual cycle phases and sexuality, well-being and mood in young healthy women.* Hormone-verified longitudinal study. https://pubmed.ncbi.nlm.nih.gov/40976232/
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
3. Does a primary or authoritative source support the mechanism or timing claim?
4. Could the wording be mistaken for a diagnosis, exact ovulation measurement, fertility guidance, or deterministic phase stereotype?

If the fourth answer is yes, the wording or feature needs to be redesigned.
