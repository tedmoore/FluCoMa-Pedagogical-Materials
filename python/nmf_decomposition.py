import librosa
import librosa.display
import numpy as np
import matplotlib.pyplot as plt
import soundfile as sf
from sklearn.decomposition import NMF
import argparse
from pathlib import Path
import json
import time

def newMagsViaSoftMask(mags,matrix):
    multiplier = 1 / np.maximum(np.sum(mags,axis=0),1e-10) # epsilon to avoid divide by zero
    print('multiplier:',multiplier)
    print('multiplier shape:',multiplier.shape)
    masks = [mags[i] * multiplier for i in range(len(mags))]
    masked_mags = [np.transpose(matrix) * masks[i] for i in range(len(mags))]
    return masked_mags

def getMags(activation,basis):
    return np.outer(basis, activation)

def combineMagsAndPhases(mags,phases):
    return mags * np.exp(1j * phases)

def istft(stft,fftSettings):
    return librosa.istft(stft,**fftSettings)
    
def resynthComponent(stft,activation,basis,outpath,fftSettings,sr):
    Y = combineMagsAndPhases(getMags(activation,basis),np.angle(stft))
    y = istft(Y,fftSettings)
    sf.write(outpath,y,sr,subtype='PCM_24')

def plot_nmf(stft, acts, bases, sr):
    plt.figure(figsize=(12, 8))

    plt.subplot(3, 1, 1)
    librosa.display.specshow(librosa.amplitude_to_db(np.abs(stft)), sr=sr, x_axis='time', y_axis='log')
    plt.title('Spectrogram')

    plt.subplot(3, 1, 2)
    for act in acts:
        plt.plot(act)
    plt.title('NMF Activations')

    plt.subplot(3, 1, 3)
    for basis in bases:
        plt.plot(basis)
    plt.title('NMF Bases')

    plt.tight_layout()
    plt.show()

def decompose(audio_path, n_components,fftSize,hopSize,resynth,plot,duration_seconds,soft_mask):

    fftSettings = {'n_fft':fftSize,'hop_length':hopSize}

    audio_buffer, sr = librosa.load(audio_path,sr=None,mono=True,duration=duration_seconds)

    print(f'path: {audio_path}\nsamplerate: {sr}')

    stft = librosa.stft(audio_buffer,**fftSettings)
    matrix = np.transpose(np.abs(stft))

    print(f'stft shape: {stft.shape[0]} mags, {stft.shape[1]} frames')

    # NMF
    nmf_args = {'solver':'mu','beta_loss':'kullback-leibler'}
    nmf_model = NMF(n_components=n_components,**nmf_args,)

    start_time = time.time()
    acts = nmf_model.fit_transform(matrix) 
    end_time = time.time()
    print(f'elapsed time: {end_time-start_time}')
    bases = nmf_model.components_
    acts = np.transpose(acts)

    audio_file_stem = Path(audio_path).stem
    
    json_path = f'{audio_file_stem}-decomposition.json'
    
    d = {}
    d['n_components'] = n_components
    d['fftSize'] = fftSize
    d['hopSize'] = hopSize
    d['sr'] = sr
    d['audio_path'] = audio_path
    d['acts'] = acts.tolist()
    d['bases'] = bases.tolist()    

    with open(json_path,'w') as f:
        f.write(json.dumps(d,indent=4))

    print(f'acts shape: {acts.shape}')
    print(f'bases shape: {bases.shape}')

    if resynth:
        if soft_mask:
            mags = [getMags(acts[i],bases[i]) for i in range(n_components)]
            masked_mags = newMagsViaSoftMask(mags,matrix)
            for i in range(n_components):
                print('masked mags shape:',masked_mags[i].shape)
                y = istft(combineMagsAndPhases(masked_mags[i],np.angle(stft)),fftSettings)
                sf.write(f'component-{i}.wav',y,sr,subtype='PCM_24')
        else:
            for i in range(n_components):
                resynthComponent(stft,acts[i],bases[i],f'component-{i}.wav',fftSettings,sr)

    if plot:
        plot_nmf(stft, acts, bases, sr)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--audio-path',type=str,required=True,help='path to audio file to decompose')
    parser.add_argument('--n-components',type=int,required=True,help='number of components to decompose into')
    parser.add_argument('--fftSize',type=int,choices=[int(2**i) for i in range(8,14)],required=False,default=1024)
    parser.add_argument('--hopSize',required=False,type=int)
    parser.add_argument('--resynth',action='store_true',help='boolean flag to resynthesize individual components after decomposition')
    parser.add_argument('--plot',action='store_true',help='boolean flag to plot spectrogram, bases, and activations')
    parser.add_argument('--duration-seconds',type=float,required=False,help='duration of audio to analyze in seconds')
    parser.add_argument('--soft-mask',action='store_true',help='boolean flag to use soft mask')
    args = parser.parse_args()

    args.hopSize = int(args.fftSize / 2) if args.hopSize is None else args.hopSize

    decompose(**vars(args))