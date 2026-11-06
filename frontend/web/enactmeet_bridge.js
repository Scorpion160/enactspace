(() => {
  const instances = new Map();
  const loaders = new Map();
  const queues = new Map();
  const operations = new Map();
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
        const timeout = setTimeout(() => {
          loaders.delete(key);
          script.remove();
          reject(new Error('Le serveur EnactMeet ne répond pas. Réessaie dans quelques instants.'));
        }, 20000);
        script.src = new URL('external_api.js', base).toString();
        script.async = true;
        script.onload = () => {
          clearTimeout(timeout);
          if (window.JitsiMeetExternalAPI) resolve(window.JitsiMeetExternalAPI);
          else { loaders.delete(key); reject(new Error('Le serveur EnactMeet n’a pas chargé la visioconférence.')); }
        };
        script.onerror = () => {
          clearTimeout(timeout);
          loaders.delete(key);
          script.remove();
          reject(new Error('La visioconférence n’a pas pu être chargée. Vérifie ta connexion puis réessaie.'));
        };
        document.head.appendChild(script);
      }));
    }
    return loaders.get(key);
  };

  const dispose = (id) => {
    operations.delete(id);
    queues.delete(id);
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

  // Older cached bundles pass only an id. Flutter platform views may live
  // inside a shadow root, so their elements are outside document.getElementById.
  const findHost = (id, root = document) => {
    const host = root.getElementById?.(id);
    if (host) return host;
    for (const element of root.querySelectorAll('*')) {
      if (!element.shadowRoot) continue;
      const nested = findHost(id, element.shadowRoot);
      if (nested) return nested;
    }
    return null;
  };

  const waitForHost = (id, host, operation) => new Promise((resolve, reject) => {
    const deadline = Date.now() + 10000;
    const check = () => {
      if (operations.get(id) !== operation) { resolve(null); return; }
      const parent = host || findHost(id);
      if (parent?.isConnected) {
        const bounds = parent.getBoundingClientRect();
        if (bounds.width > 0 && bounds.height > 0) { resolve(parent); return; }
      }
      if (Date.now() >= deadline) {
        reject(new Error('La salle n’a pas pu s’afficher. Reviens à la réunion puis réessaie.'));
        return;
      }
      setTimeout(check, 25);
    };
    check();
  });

  window.enactMeetCreate = async (id, serverUrl, optionsJson, host) => {
    dispose(id);
    const operation = {};
    operations.set(id, operation);
    const emitActive = (type, payload = {}) => {
      if (operations.get(id) === operation) emit(id, type, payload);
    };
    try {
      const options = JSON.parse(optionsJson);
      const parent = await waitForHost(id, host, operation);
      if (!parent) return;
      parent.replaceChildren();

      const ExternalApi = await loadApi(serverUrl);
      if (operations.get(id) !== operation) return;
      if (!ExternalApi) throw new Error('Jitsi External API indisponible.');
      if (!await waitForHost(id, parent, operation)) return;
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
        emitActive('joined', event || {});
      });
      api.addListener('participantJoined', (event) => {
        emitActive('participantJoined', event || {});
      });
      api.addListener('participantLeft', (event) => {
        emitActive('participantLeft', event || {});
      });
      api.addListener('participantRoleChanged', (event) => {
        const role = event?.role || '';
        if (operations.get(id) !== operation) return;
        emitActive('roleChanged', event || {});
        if (options.lobbyEnabled && role === 'moderator') {
          try {
            api.executeCommand('toggleLobby', true);
          } catch (error) {
            emitActive('warning', {
              message: error?.message || 'Le lobby Jitsi n’a pas pu être activé automatiquement.',
            });
          }
        }
      });
      api.addListener('videoConferenceLeft', (event) => {
        emitActive('left', event || {});
      });
      api.addListener('readyToClose', () => {
        emitActive('readyToClose');
      });
      emitActive('ready');
    } catch (error) {
      if (operations.get(id) !== operation) return;
      operations.delete(id);
      const api = instances.get(id);
      if (api) { try { api.dispose(); } catch (_) {} instances.delete(id); }
      emit(id, 'error', {
        message: error?.message || String(error),
      });
    }
  };
})();
