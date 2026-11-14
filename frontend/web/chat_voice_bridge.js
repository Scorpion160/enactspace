(() => {
  let session = null;

  const stopTracks = (stream) => {
    if (!stream) return;
    for (const track of stream.getTracks()) track.stop();
  };

  const chooseMimeType = () => {
    const candidates = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/mp4',
    ];
    return candidates.find((value) => MediaRecorder.isTypeSupported(value)) || '';
  };

  const encodeBase64 = (buffer) => {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    const chunkSize = 0x8000;
    for (let offset = 0; offset < bytes.length; offset += chunkSize) {
      binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
    }
    return btoa(binary);
  };

  window.enactChatVoiceStart = async () => {
    if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === 'undefined') {
      throw new Error('L’enregistrement vocal n’est pas pris en charge par ce navigateur.');
    }
    if (session) {
      try { session.recorder.stop(); } catch (_) {}
      stopTracks(session.stream);
      session = null;
    }

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const mimeType = chooseMimeType();
    const recorder = mimeType
      ? new MediaRecorder(stream, { mimeType })
      : new MediaRecorder(stream);
    const current = {
      recorder,
      stream,
      chunks: [],
      startedAt: Date.now(),
      mimeType: recorder.mimeType || mimeType || 'audio/webm',
    };
    recorder.addEventListener('dataavailable', (event) => {
      if (event.data && event.data.size > 0) current.chunks.push(event.data);
    });
    recorder.start(250);
    session = current;
    return 'true';
  };

  window.enactChatVoiceStop = async () => {
    const current = session;
    if (!current) throw new Error('Aucun enregistrement vocal en cours.');
    session = null;

    return await new Promise((resolve, reject) => {
      const cleanup = () => stopTracks(current.stream);
      current.recorder.addEventListener('error', (event) => {
        cleanup();
        reject(event.error || new Error('Erreur pendant l’enregistrement vocal.'));
      }, { once: true });
      current.recorder.addEventListener('stop', async () => {
        try {
          const mimeType = current.recorder.mimeType || current.mimeType || 'audio/webm';
          const blob = new Blob(current.chunks, { type: mimeType });
          if (!blob.size) throw new Error('Le vocal enregistré est vide.');
          const buffer = await blob.arrayBuffer();
          const extension = mimeType.includes('ogg')
            ? 'ogg'
            : mimeType.includes('mp4')
            ? 'm4a'
            : 'webm';
          const durationSeconds = Math.max(
            1,
            Math.round((Date.now() - current.startedAt) / 1000),
          );
          resolve(JSON.stringify({
            base64: encodeBase64(buffer),
            mimeType,
            name: `vocal_enactspace.${extension}`,
            durationSeconds,
          }));
        } catch (error) {
          reject(error);
        } finally {
          cleanup();
        }
      }, { once: true });
      current.recorder.stop();
    });
  };

  window.enactChatVoiceCancel = async () => {
    const current = session;
    session = null;
    if (!current) return 'ok';
    try {
      if (current.recorder.state !== 'inactive') current.recorder.stop();
    } catch (_) {}
    stopTracks(current.stream);
    return 'ok';
  };
})();
