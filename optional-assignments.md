### After Day 1

1. Use the classifier code to train your own sounds using more than 2 categories. If you’re unsure what sounds to try it with, try classifying different vowels that you sing into the microphone!
2. Once you you have the classifier working, use the MLPClassifier’s predictions to control something musically or visually (the color of a square on the screen?).
3. Validate the results of your trained MLPClassifier by reserving some testing data separate from your training data and seeing how it performs on the test set (do this manually as opposed to using the @validate attribute).
4. Use the “MLPRegressor Predicting FM Synth Values” code to practice training a neural network on this difficult task. Tweak all the parameters and see how the error responds. Clear the neural network a few times and try to train it with different parameters.
5. Using the first code we looked at today (MLPRegressor that controls a synth), put your own synthesizer in there (with a number of control parameters different than 10) and control it as a performance instrument from the 2D space.

### After Day 2

1. Use FluidBufNMF to decompose a sound of your choosing. What happens when you specify 2 components? 3? 4? More? Does it decompose into sound objects the way you might expect? If not, why this might be the case?
2. After doing some decomposition with FluidBufNMF, try playing back all the decomposed components at the same time but applying different audio FX to each (delay one, add reverb to one, pitch shift one, etc…).
3. Use FluidAmpSlice to randomly assign a new audio FX to a real-time audio signal whenever there is an onset. For audio FX use the decomposition tools we saw today (FluidHPSS, FluidSines, and/or NMFFilter) along with others. For additional complexity, when there is an onset, also randomly change some of the parameters of the FX.
4. Instead of training an MLPRegressor to control synthesis parameters (like Monday) train it to control various parameters of the real-time FluidSines algorithm and use it to morph the sound while audio is flowing through FluidSines!

### After Day 3

1. Keep looking at the 02-plot code–in particular try putting some of your sounds in there. Change the @select analyses to some different ones (both in FluidSpectralShape and FluidBufStats) and see how it changes the plot!
2. Extend 02-plot, to offer different slicers prior to the analysis and then experiment with different slicers for different sounds. (You might also make the slicer-analysis pipeline more fully connected so it does all of it automatically.)
3. Using the fabulous drum loop, decompose it using NMF prior to slicing and spectral centroid analysis so that each drum hit of each drum surface is its own slice! (Note that you’ll have to use FluidBufCompose to get your 3 components buffers allocated into one buffer to give to a slicer!)

### After Day 4

1. Use your own sounds in the dimensionality reduction & plotter patch. Use PCA and UMAP to explore 2 dimensional spaces of the sounds. Choose a plot you find musically interesting or useful and save the plotted dataset to disk using a write message.
2. Attach a physical controller (TouchOSC or MIDI?) to the plot and perform it as an instrument. Record into a buffer for a few minutes…and then use that buffer to slice, analyze, dimensionally reduce, and plot! Recurse to taste.
3. Starting from a dataset of 13 MFCCs. Use PCA to reduce the number of dimensions from 13 to 8, then use UMAP to reduce the number of dimensions from 8 to 2. Is it different than using UMAP to go from 13 directly to 2? Is it better?