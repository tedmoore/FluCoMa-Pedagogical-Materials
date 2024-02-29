import soundfile as sf
import numpy as np
import argparse
import json
import librosa

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='NMF resynthesis')
    parser.add_argument('--bases-data',type=str,required=True,help='path to json file containing NMF decomposition')
    parser.add_argument('--basis-index',type=int,required=True,help='index of basis to resynthesize')
    parser.add_argument('--activations-data',type=str,required=True,help='path to json file containing NMF decomposition')
    parser.add_argument('--activation-index',type=int,required=True,help='index of activation to resynthesize')
    parser.add_argument('--output-path',type=str,required=True,help='path to write resynthesized audio file')
    args = parser.parse_args()

    with open(args.bases_data,'r') as f:
        bases_data = json.loads(f.read())

    with open(args.activations_data,'r') as f:
        activations_data = json.loads(f.read())

    basis = bases_data['bases'][args.basis_index]
    activations = activations_data['acts'][args.activation_index]

    resynthesized_mags = np.outer(basis,activations)
    y = librosa.griffinlim(resynthesized_mags,hop_length=activations_data['hop_length'])
    sf.write(args.output_path,y,bases_data['sr'],subtype='PCM_24')
    