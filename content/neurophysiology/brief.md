# Neural-signal envelopes and movement kinematics

**Status:** Completed technical pilot on one participant and one day. Multi-participant validation and formal condition comparison were not performed.

**One-sentence card copy:** Built a reproducible Python pipeline to examine how narrow-band neural-signal envelopes relate to continuous movement kinematics using mutual information and phase-randomized controls.

## Research question

Which signal channels and frequency ranges contain information about movement angle or velocity? The pilot mapped candidate relationships; it did not test a clinical effect or train a predictive model.

## Data and approach

- Started from already prepared, synchronized multichannel FIF recordings. I did not collect the data, design the clinical protocol, or perform the original artifact cleaning.
- Analysed 12 motor recordings against two continuous kinematic targets, giving 24 primary computational runs. Each produced noninvasive and invasive summaries; the final report loaded 48 expected result groups.
- Resampled from 1000 to 250 Hz with a Nyquist check, analysed overlapping 3 Hz bands at 1 Hz steps, then extracted Hilbert amplitude envelopes.
- Estimated mutual information (MI) between each envelope and movement target. Used 200 phase-randomized target surrogates per configuration to express the observed MI relative to a surrogate distribution as zMI.
- Parallelized channel-by-band computations and saved parameters, logs, manifests, numerical outputs, and summary plots so expensive computation and figure generation could be run separately.

## What was demonstrated

The analysis pipeline completed the planned pilot runs, retained an auditable record of their settings and status, and generated channel/frequency summaries. Absolute MI had a frequency-dependent baseline that made direct comparison difficult; the surrogate baseline made the exploratory maps more interpretable.

## Personal contribution

I inspected the provided FIF structure, designed the computational frequency grid and surrogate normalization, implemented the MI and plotting pipeline in Python, ran and checked the batch computations, and interpreted the descriptive results. The source recordings and clinical data collection were outside my role.

## Limits to retain on the page

- One participant and one day: no population-level inference.
- No paired pre/post statistical test or multiple-comparison correction; do not claim a neurofeedback effect.
- zMI above an informal threshold is a visualization aid, not corrected statistical significance.
- Lagged MI, SPoC, and predictive modelling were discussed but not implemented in this pilot.
- A public page should use generic labels for recordings and conditions and should not show raw or reconstructable participant data.

## Visual story

1. Compact pipeline diagram: synchronized signals and kinematics → frequency bands → envelopes → real/surrogate MI → zMI map.
2. One carefully relabelled topomap or a fully synthetic topomap to explain spatial structure.
3. One channel/band summary heatmap with a caption that says the values are descriptive.
4. A small provenance panel showing that 24 runs completed and generated both signal-group summaries, without exposing recording IDs or paths.

## Portfolio wording

“Exploratory surrogate-normalized mutual information between narrow-band neural-signal envelopes and continuous movement kinematics. This one-participant technical pilot demonstrates a reproducible analysis workflow; its maps are descriptive and do not constitute a corrected significance test.”
