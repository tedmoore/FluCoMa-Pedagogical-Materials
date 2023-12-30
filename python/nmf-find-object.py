import librosa
import librosa.display
import numpy as np
import matplotlib.pyplot as plt
import soundfile as sf

def resynthComponent(stft,basis,activation,outpath,fftSettings):
    Y = np.outer(basis, activation) * np.exp(1j * np.angle(stft))
    y = librosa.istft(Y,**fftSettings)
    sf.write(outpath,y,sr,subtype='PCM_24')

audio_file_path = '../media/Nicol-LoopE-M.wav'
n_components = 3
duration_seconds = None

# audio_file_path = '../media/Tremblay-BaB-SoundscapeGolcarWithDog.wav' 
# n_components = 2

sr = 44100
fftSettings = {'n_fft':1024,'hop_length':512}

excerpt, sr = librosa.load(audio_file_path,sr=sr,duration=duration_seconds,mono=True)
y, sr = librosa.load(audio_file_path,sr=sr)

print(audio_file_path,sr)

excerpt_stft = librosa.stft(excerpt,**fftSettings)

print(f'stft shape: {excerpt_stft.shape[0]} mags, {excerpt_stft.shape[1]} frames')

bases, activations = librosa.decompose.decompose(np.abs(excerpt_stft), n_components=n_components)
bases = np.transpose(bases)

print(f'bases shape: {bases.shape}')
print(f'activations shape: {activations.shape}')

for i in range(n_components):
    resynthComponent(excerpt_stft,bases[i],activations[i],f'librosa-component-{i}.wav',fftSettings)

plt.figure(figsize=(12, 8))

plt.subplot(3, 1, 1)
librosa.display.specshow(librosa.amplitude_to_db(np.abs(excerpt_stft)), sr=sr, x_axis='time', y_axis='log')
plt.title('Excerpt Spectrogram')

plt.subplot(3, 1, 2)
for basis in bases:
    plt.plot(basis)
plt.title('Excerpt NMF Bases')

plt.subplot(3, 1, 3)
for activation in activations:
    plt.plot(activation)
plt.title('Excerpt NMF Activations')

plt.tight_layout()
plt.show()