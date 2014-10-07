# Many thanks to [Muaz Khan](https://github.com/muaz-khan) for introducing me to WebRTC video conferencing.
# [This](https://developer.mozilla.org/en-US/docs/Web/Guide/API/WebRTC/WebRTC_architecture) is also really useful.

window.CAMWIRE =
  DEBUG: false

window.CAMWIRE.main = do
  RTCPeerConnection = window.mozRTCPeerConnection || window.webkitRTCPeerConnection
  RTCSessionDescription = window.mozRTCSessionDescription || window.RTCSessionDescription
  RTCIceCandidate = window.mozRTCIceCandidate || window.RTCIceCandidate
  navigator.getUserMedia = navigator.mozGetUserMedia || navigator.webkitGetUserMedia

  isFirefox = !!navigator.mozGetUserMedia
  isChrome = !!navigator.webkitGetUserMedia

  STUN = {url: if isChrome then 'stun:stun.l.google.com:19302' else 'stun:23.21.150.121'}
  TURN = {url: 'turn:homeo@turn.bistri.com:80', credential: 'homeo'}
  iceServers = {iceServers: [STUN]};
  if isChrome
    if parseInt (navigator.userAgent.match /Chrom(e|ium)\/([0-9]+)\./)[2] >= 28
      TURN = {url: 'turn:turn.bistri.com:80', credential: 'homeo', username: 'homeo'}
    iceServers.iceServers = [STUN, TURN]

  class VideoChat
    ->
      @user = {}

      self = @
      window.addEventListener \beforeunload, !-> self.part!

    onaddstream: (video, stream) ->
    onuserleft: (user-id) ->

    create-cam-node = (id, stream) ->
      video = document.createElement \video
        ..id = id
        ..[if isFirefox then \mozSrcObject else \src] = if isFirefox then stream else window.webkitURL.createObjectURL stream
        ..autoplay = true
        ..controls = false
        ..play!

    build-stream-handler: (user-id, callback) ->
      self = @
      (stream) !->
        stream.onended = !-> self.onuserleft user-id

        node = create-cam-node user-id, stream

        if user-id is self.user.id
          node
            ..muted = true
            ..volume= 0

        self.onaddstream node, stream

        callback? stream

    _getUserMedia: (callback) !->
      constraints =
        audio: true
        video: true
      onstream = @build-stream-handler @user.id, callback
      onerror = !-> window.alert it

      navigator.getUserMedia constraints, onstream, onerror

    set-signaller: -> @sig = it

    join: (roomid) !->
      if !@sig?
        console.error 'No signaller set!'
        return

      self = @
      stream <-! @_getUserMedia
      self.stream = stream
      self.sig.signal \join, {roomid}

    part: !->
      if !@sig?
        console.error 'No signaller set!'
        return

      @sig.signal \part
      @stream?.stop!


  class SignallerSocketIO
    (@vc) ->
      @peers = {}

    connect: (address, callback) !->
      if !io?
        window.alert '''Unable to connect to signalling server.
          Chances are everything is OK on your end and the server is just down for some reason.
          If it's not up again soon, email me at yousef@amar.io.'''
        return

      self = @

      socket = io.connect address

      @signal = (event, data, callback) !->
        if !self.vc.user.id?
          console.error 'No UID assigned by server!'
          return

        data = data || {}
        console.log '> ', event, data
        socket.emit event, data, callback

      socket
        ..on \uid, (uid) !->
          console.log '< ', \uid, uid
          self.vc.user.id = uid
          callback uid

        ..on \join, (user-id) !->
          console.log '< ', \join, user-id
          self.peers[user-id] = new Peer user-id, self
            ..addStream self.vc.stream
            ..createOffer!

        ..on \part, (user-id) !->
          console.log '< ', \part, user-id
          delete self.peers[user-id]
          self.vc.onuserleft user-id
          return

        ..on \sdp, (data) !->
          console.log '< ', \sdp, data
          sdp = data.sdp

          if sdp.type is \offer
            self.peers[data.user-id] = new Peer data.from, self
              ..addStream self.vc.stream
              ..createAnswer sdp

          if sdp.type is \answer
            self.peers[data.from].setRemoteDescription sdp

        ..on \ice, (data) !->
          console.log '< ', \ice, data
          self.peers[data.from]?.addIceCandidate data.candidate

    signal: !-> console.error 'No signalling function set!'


  class Peer
    (@user-id, @sig) ->
      @conn = conn = new RTCPeerConnection iceServers, {optional: [{DtlsSrtpKeyAgreement: true}]}
      self = @
      conn.onaddstream = do ->
        onstream = sig.vc.build-stream-handler user-id
        (event) !-> onstream event.stream
      conn.onicecandidate = (event) !-> if !event.candidate then self.onsdp conn.localDescription, user-id else self.onicecandidate event.candidate, user-id
      conn.ongatheringchange = (event) !-> event.currentTarget && event.currentTarget.iceGatheringState is \complete && self.onsdp conn.localDescription, user-id

    addStream: !->
      @conn.addStream it

    mediaConstraints =
      optional: []
      mandatory:
        OfferToReceiveAudio: true
        OfferToReceiveVideo: true

    createOffer: !->
      self = @
      sdp <-! @conn.createOffer _, onSdpError, mediaConstraints
      self.conn.setLocalDescription sdp
      isFirefox && self.onsdp sdp, self.user-id

    createAnswer: (sdp) !->
      self = @
      @conn.setRemoteDescription new RTCSessionDescription sdp, onSdpSuccess, onSdpError
      sdp <-! @conn.createAnswer _, onSdpError, mediaConstraints
      self.conn.setLocalDescription sdp
      self.onsdp sdp, self.user-id

    setRemoteDescription: (sdp) !->
      @conn.setRemoteDescription new RTCSessionDescription sdp, onSdpSuccess, onSdpError

    addIceCandidate: (candidate) !->
      @conn.addIceCandidate new RTCIceCandidate {candidate.sdpMLineIndex, candidate.candidate}

    onicecandidate: (candidate, to) !-> @sig.signal \ice, {candidate, to}
    onsdp: (sdp, to) !-> @sig.signal \sdp, {sdp, to}
    onSdpSuccess = ->
    onSdpError = !-> console.error 'sdp error:', it.name, it.message

  ->
    vc = new VideoChat!

    thumbs = document.getElementById \thumbnails

    large = null

    set-large = (node) !->
      if large?
        thumbs.appendChild large
        large.play!
      large := node
      document.body.appendChild large
      large.play!

    vc.onaddstream = (video, stream) !->
      video.onclick = !-> set-large video
      thumbs.appendChild video

    vc.onuserleft = !->
      video = document.getElementById it
      video && video.parentNode.removeChild video
      if video is large then large := null

    #get-vars = {}
    #window.location.href.replace /[?&]+([^=&]+)=([^&]*)/gi, (m,key,value) !-> get-vars[key] = value
    #roomID = get-vars[\room]

    roomID = (window.location.href.match /[^/]+$/g)?[0]
    if not roomID
      roomID := 'xxxxxx'.replace /[x]/g, -> (Math.random!*36.|.0).toString 36
      window.history.replaceState {}, "New Room ID", "/#{roomID}"

    <-! vc.set-signaller new SignallerSocketIO vc
      .connect if window.CAMWIRE.DEBUG then "http://localhost:9980" else "http://camwi.re:9980", _
    console.log "Joining room #{roomID}"
    vc.join "camwire-#{roomID}"
