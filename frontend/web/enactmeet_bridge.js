(() => {
  const instances = new Map();
  const loaders = new Map();
  const queues = new Map();
  const eventName = 'enactmeet-event';

  const emit = (id, type, payload = {}) => {
    const event = { id, type, ...payload };
    const queue = queues.get(id) || [];
    queue.push(event);
    if (queue.length > 100) queue.splice(0, queue.length - 100);
    queues.set(id, queue);
    window.dispatchEvent(new CustomEvent(eventName, {
      detail: JSON.stringify(event),
    }));
  };

  window.enactMeetTakeEvents = (id) => {
    const queue = queues.get(id) || [];
    queues.set(id, []);
    return JSON.stringify(queue);
  };

  const baseUrl = (serverUrl) => {
    const value = serverUrl.endsWith('/') ? serverUrl : `${serverUrl}/`;
    return new URL(value);
  };

  const loadApi = async (serverUrl) => {
    if (window.JitsiMeetExternalAPI) return window.JitsiMeetExternalAPI;
    const base = baseUrl(serverUrl);
    const key = base.origin + base.pathname;
    if (!loaders.has(key)) {
      loaders.set(key, new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = new URL('external_api.js', base).toString();
        script.async = true;
        script.onload = () => resolve(window.JitsiMeetExternalAPI);
        script.onerror = () => reject(new Error('Impossible de charger Jitsi External API.'));
        document.head.appendChild(script);
      }));
    }
    return loaders.get(key);
  };

  const dispose = (id) => {
    const api = instances.get(id);
    if (!api) return;
    try {
      api.dispose();
    } catch (_) {
      // Best effort cleanup; Flutter still removes the host element.
    }
    instances.delete(id);
  };

  window.enactMeetDispose = (id) => dispose(id);

  window.enactMeetCreate = async (id, serverUrl, optionsJson) => {
    try {
      dispose(id);
      const options = JSON.parse(optionsJson);
      const parent = document.getElementById(id);
      if (!parent) throw new Error('Conteneur EnactMeet introuvable.');
      parent.replaceChildren();

      const ExternalApi = await loadApi(serverUrl);
      if (!ExternalApi) throw new Error('Jitsi External API indisponible.');
      const server = baseUrl(serverUrl);
      const configOverwrite = {
        subject: options.subject || 'EnactMeet',
        startWithAudioMuted: !!options.startWithAudioMuted,
        startWithVideoMuted: !!options.startWithVideoMuted,
        disableDeepLinking: true,
        disableInviteFunctions: true,
        requireDisplayName: true,
        prejoinConfig: {
          enabled: true,
          hideDisplayName: true,
        },
        lobby: {
          autoKnock: true,
          enableChat: true,
        },
      };

      const roomPrefix = server.pathname.replace(/^\/+|\/+$/g, '');
      const roomName = roomPrefix
        ? `${roomPrefix}/${options.roomName}`
        : options.roomName;
      const api = new ExternalApi(server.host, {
        roomName,
        parentNode: parent,
        width: '100%',
        height: '100%',
        jwt: options.jwt || undefined,
        userInfo: {
          displayName: options.displayName,
          email: options.email,
          avatarURL: options.avatarUrl || undefined,
        },
        configOverwrite,
      });
      instances.set(id, api);

      api.addListener('videoConferenceJoined', (event) => {
        emit(id, 'joined', event || {});
      });
      api.addListener('participantJoined', (event) => {
        emit(id, 'participantJoined', event || {});
      });
      api.addListener('participantLeft', (event) => {
        emit(id, 'participantLeft', event || {});
      });
      api.addListener('participantRoleChanged', (event) => {
        const role = event?.role || '';
        emit(id, 'roleChanged', event || {});
        if (options.lobbyEnabled && role === 'moderator') {
          try {
            api.executeCommand('toggleLobby', true);
          } catch (error) {
            emit(id, 'warning', {
              message: error?.message || 'Le lobby Jitsi n’a pas pu être activé automatiquement.',
            });
          }
        }
      });
      api.addListener('videoConferenceLeft', (event) => {
        emit(id, 'left', event || {});
      });
      api.addListener('readyToClose', () => {
        emit(id, 'readyToClose');
      });
      emit(id, 'ready');
    } catch (error) {
      emit(id, 'error', {
        message: error?.message || String(error),
      });
    }
  };
})();
