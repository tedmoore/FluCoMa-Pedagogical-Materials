# Summer Workshop 2024 Daily Outline

This is the *actuals* of what happened each day, reflecting what adjustments were made during the week.

## Monday

* Intro
* MLPRegressor
  * controlling a synth with 10 control parameters from xy space
  * controlling a synth with other media such as eyeball "tracking"
* MLPClassifier
  * classifying timbre in real-time (oboe vs. trombone)
* Validating a trained model
* Inspecting the interaction of data and features on a plot to look for what analyses might be useful for achieving certain tasks
* MFCC computation and intuition

## Tuesday

* MLPRegressor
  * predicting frequency modulation parameters from MFCC analyses
* Advanced MLP parameters
* AmpSlice (and other slicers)
* FluidSines & FluidSineFeature
* Harmonic Percussive Source Separation (HPSS)
* NMF
  * decomposition
  * bases
  * activations
  * seeding bases and activations including automatic melodic transcription
  * how masks are used in the resynthesis process

## Wednesday

* Non-real-time buffer audio analyses
* BufStats
* FluidPlotter
* KDTree
* Principal Component Analysis (PCA)
* UMAP (Uniform Manifold Approximation and Projection)

## Thursday

* UMAP to 1 dimension
* BufFlatten
* FluidGrid
* Concatenative Synthesis
* "Distance" as a measure of "Similarity"
* FluidNormalize
* FluidStandardize
* FluidRobustScale
* Autoencoder
  * latent space
  * predicting wavetables
  * predicting FFT magnitudes

## Friday

* AudioTransport
* KMeans
  * clustering
  * distance
* Automatic Buffer & Dataset Management (Max only)
* Reflecting on Human vs. Computer Assumptions about Machine Listening
* Weighted Statistics in BufStats
* NMF Tools in Python
  * resynthesis with mismatched activations & bases