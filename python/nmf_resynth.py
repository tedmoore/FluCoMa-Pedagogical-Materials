import soundfile as sf
import numpy as np
import argparse
import json
import librosa
from nmf_decomposition import resynthComponent

def resynthFromFiles(bases_data,activations_data,basis_index,activation_index,output_path):
    with open(args.bases_data,'r') as f:
        bases_data = json.loads(f.read())

    with open(args.activations_data,'r') as g:
        activations_data = json.loads(g.read())

    fftSettings = {'n_fft':bases_data['fftSize'],'hop_length':bases_data['hopSize']}
    
    audio_buffer, _ = librosa.load(activations_data['audio_path'],sr=None,mono=True)
    stft = librosa.stft(audio_buffer,**fftSettings)

    activation = np.array(activations_data['acts'][args.activation_index])
    basis = np.array(bases_data['bases'][args.basis_index])
    
    print(stft.shape)
    print(basis.shape)
    print(activation.shape)
                   
    resynthComponent(stft,activation,basis,args.output_path,fftSettings,sr=activations_data['sr'])

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='NMF resynthesis')
    parser.add_argument('--bases-data',type=str,required=True,help='path to json file containing NMF decomposition')
    parser.add_argument('--basis-index',type=int,required=True,help='index of basis to resynthesize')
    parser.add_argument('--activations-data',type=str,required=True,help='path to json file containing NMF decomposition')
    parser.add_argument('--activation-index',type=int,required=True,help='index of activation to resynthesize')
    parser.add_argument('--output-path',type=str,required=True,help='path to write resynthesized audio file')
    args = parser.parse_args()

    resynthFromFiles(args.bases_data,args.activations_data,args.basis_index,args.activation_index,args.output_path)