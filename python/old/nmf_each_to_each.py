import librosa
import numpy as np
import soundfile as sf
import librosa.display
import IPython.display as ipd
import matplotlib.pyplot as plt
import scipy
import sys
import os

# first argument is the path of the file to analyze
path = sys.argv[1]

filename = os.path.split(path)[-1].split('.')[0]
sound, sr = librosa.load(path)
stft = librosa.stft(sound)

# second argument is the number of components you want to analyze for
n_components = int(sys.argv[2])

X = np.absolute(stft)
# librosa.decompose.decompose returns: components (W), activation functions (H)
W, H = librosa.decompose.decompose(X,n_components=n_components,sort=True)

for activation_function in range(n_components):
    for component in range(n_components):
        print('activation_function '+str(activation_function)+', component '+str(component))
        # the W of one and the H of another
        Y = scipy.outer(W[:,component], H[activation_function])*np.exp(1j*np.angle(stft))
        y = librosa.istft(Y)
        sf.write(filename+'_actFunc_'+str(activation_function)+'_comp_'+str(component)+'.wav',y,sr)
