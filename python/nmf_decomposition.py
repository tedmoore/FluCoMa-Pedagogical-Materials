import librosa
import librosa.display
import numpy as np
import matplotlib.pyplot as plt
import soundfile as sf
from sklearn.decomposition import NMF
import argparse
from pathlib import Path
import json

def make_mags_from_basis_and_activation(activation,basis):
    return np.outer(basis, activation)

def balance_mags_via_softmask(resynthesized_mags,mags_to_mask):
    multiplier = 1 / np.maximum(np.sum(resynthesized_mags,axis=0),1e-10) # epsilon to avoid divide by zero
    return multiplier * resynthesized_mags * mags_to_mask

def make_complex_matrix_from_mags_and_phases(mags,phases):
    return mags * np.exp(1j * phases)

def istft(complex_stft,fftSettings):
    return librosa.istft(complex_stft,**fftSettings)
    
def plot_nmf(stft, activations, bases, sr):
    plt.figure(figsize=(12, 8))

    plt.subplot(3, 1, 1)
    librosa.display.specshow(librosa.amplitude_to_db(np.abs(stft)), sr=sr, x_axis='time', y_axis='log')
    plt.title('Spectrogram')

    plt.subplot(3, 1, 2)
    for act in activations:
        plt.plot(act)
    plt.title('NMF Activations')

    plt.subplot(3, 1, 3)
    for basis in bases:
        plt.plot(basis)
    plt.title('NMF Bases')

    plt.tight_layout()
    plt.show()

def decompose(mags, n_components):

    nmf_args = {'solver':'mu','beta_loss':'kullback-leibler'}
    nmf_model = NMF(n_components=n_components,**nmf_args,)

    acts = nmf_model.fit_transform(np.transpose(mags)) 
    bases = nmf_model.components_
    acts = np.transpose(acts)

    return bases, acts

def save_decomposition_to_json(audio_path, n_components, bases, activations, fftSettings):
    audio_file_stem = Path(audio_path).stem
    
    json_path = f'{audio_file_stem}-decomposition.json'
    
    d = {}
    d['n_components'] = n_components
    d['n_fft'] = fftSettings['n_fft']
    d['hop_length'] = fftSettings['hop_length']
    d['sr'] = sr
    d['audio_path'] = audio_path
    d['acts'] = activations.tolist()
    d['bases'] = bases.tolist()    

    with open(json_path,'w') as f:
        f.write(json.dumps(d,indent=4))
    
    return json_path

def write_to_file(y,output_path,sr):
    sf.write(output_path,y,sr,subtype='PCM_24')

def create_fftSettings_from_args(args):
    fftSettings = {}
    fftSettings['n_fft'] = args.n_fft
    fftSettings['hop_length'] = int(args.n_fft / 2) if args.hop_length is None else args.hop_length
    return fftSettings

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--audio-path',type=str,required=True,help='path to audio file to decompose')
    parser.add_argument('--n-components',type=int,required=True,help='number of components to decompose into')
    parser.add_argument('--n_fft',type=int,choices=[int(2**i) for i in range(8,14)],required=False,default=1024)
    parser.add_argument('--hop_length',required=False,type=int)
    parser.add_argument('--resynth',action='store_true',help='boolean flag to resynthesize individual components after decomposition')
    parser.add_argument('--plot',action='store_true',help='boolean flag to plot spectrogram, bases, and activations')
    parser.add_argument('--duration-seconds',type=float,required=False,help='duration of audio to analyze in seconds')
    args = parser.parse_args()

    fftSettings = create_fftSettings_from_args(args)

    # get audio buffer and sample rate
    audio_buffer, sr = librosa.load(args.audio_path,sr=None,mono=True,duration=args.duration_seconds)
    stft = librosa.stft(audio_buffer,**fftSettings)
    original_mags = np.abs(stft)
    original_phases = np.angle(stft)

    # decompose audio buffer into bases & activations
    bases, activations = decompose(original_mags,args.n_components)

    save_decomposition_to_json(args.audio_path,args.n_components,bases,activations,fftSettings)
    
    if args.resynth:
        resynthesized_mags = [make_mags_from_basis_and_activation(activations[i],bases[i]) for i in range(args.n_components)]
        masked_mags = balance_mags_via_softmask(resynthesized_mags,original_mags)
        for i in range(args.n_components):
            y = istft(make_complex_matrix_from_mags_and_phases(masked_mags[i],original_phases),fftSettings)
            write_to_file(y,f'component-{i}.wav',sr)

    if args.plot:
        plot_nmf(stft, activations, bases, sr)