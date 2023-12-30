import librosa
import numpy as np
import librosa.display
import IPython.display as ipd
import matplotlib.pyplot as plt
import soundfile as sf
import scipy
import sys
import os

#paths = ['audio/sound02.wav','audio/sound03.wav']
#n_components = 3
# first two arguments are the two paths of the files you're going to swap
# feature curves and spectra with...
paths = [sys.argv[1],sys.argv[2]]

# third argument is the number of components to analyze for
n_components = int(sys.argv[3])

sounds = []

for path in paths:
    sound, sr = librosa.load(path,sr=44100)
    sounds.append({'sound':sound,'sr':sr})

shorter_length = min(len(sounds[0]['sound']),len(sounds[1]['sound']))

for sound in sounds:
    sound['sound'] = sound['sound'][:shorter_length]
    stft = librosa.stft(sound['sound'])
    abs_stft = np.absolute(stft)
    W, H = librosa.decompose.decompose(abs_stft,n_components=n_components,sort=True)
    sound['stft'] = stft
    sound['abs_stft'] = abs_stft
    sound['W'] = W
    sound['H'] = H

for n in range(n_components):
    for i in range(2):
        first = i
        second = (i+1) % 2

        W1 = sounds[first]['W']
        W2 = sounds[second]['W']

        H1 = sounds[first]['H']
        H2 = sounds[second]['H']

        # first i'll try phases from the first one
        stft = sounds[first]['stft']

        filename = os.path.split(paths[first])[-1].split('.')[0] + '_' + os.path.split(paths[second])[-1].split('.')[0]
        Y = scipy.outer(W1[:,n], H2[n])*np.exp(1j*np.angle(stft))
        y = librosa.istft(Y)
        sf.write(filename+'_nmf_n='+str(n_components)+'_#'+str(n+1)+'.wav',y,sr)
