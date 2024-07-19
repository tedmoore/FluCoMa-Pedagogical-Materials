import librosa
import numpy as np
from sklearn.decomposition import NMF
import argparse
import matplotlib.pyplot as plt

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--audio-path',type=str,required=True,help='path to audio file to decompose')
    parser.add_argument('--n-components',type=int,required=True,help='number of components to decompose into')
    args = parser.parse_args()

    y, sr = librosa.load(args.audio_path, sr=None,mono=True)
    chroma = librosa.feature.chroma_cqt(y=y, sr=sr)
    
    nmf = NMF(n_components=args.n_components,max_iter=1000)
    nmf.fit(chroma,)
    W = nmf.transform(chroma).T
    H = nmf.components_
    
    plt.figure(figsize=(12, 8))

    plt.subplot(3, 1, 1)
    librosa.display.specshow(chroma, y_axis='chroma', x_axis='time', sr=sr)
    plt.title('Chromagram')

    plt.subplot(3, 1, 2)
    for h in H:
        plt.plot(h)
    plt.title('H')
    
    plt.subplot(3, 1, 3)
    for w in W:
        plt.plot(w)
    plt.title('W')

    plt.tight_layout()
    plt.show()