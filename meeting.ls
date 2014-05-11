# 2013, Muaz Khan - https://github.com/muaz-khan
# MIT License     - https://www.webrtc-experiment.com/licence/
# Documentation   - https://github.com/muaz-khan/WebRTC-Experiment/tree/master/meeting
# Modified by Yousef Amar <yousef@amar.io> on 2014-05-09

do ->
  # a middle-agent between public API and the Signaler object
  window.Meeting = !->
    signaler = null
    self = @

    # get alerted for each new meeting
    @onmeeting = (room) !->
      if not self.detectedRoom
        self.detectedRoom = true
        self.meet room

    initSignaler = !-> signaler := new Signaler self

    captureUserMedia = (callback) !->
      constraints =
        audio: true
        video: true

      onstream = (stream) !->
        stream.onended = !->
          if self.onuserleft
            self.onuserleft \self

        self.stream = stream

        video = document.createElement \video
        video.id = \self
        video[if isFirefox then \mozSrcObject else \src] = if isFirefox then stream else window.webkitURL.createObjectURL stream
        video.autoplay = true
        video.controls = false
        video.muted = true
        video.volume= 0
        video.play!

        self.onaddstream {
          video: video
          stream: stream
          userid: \self
          type: \local
        }

        callback stream

      onerror = !-> console.error it

      navigator.getUserMedia constraints, onstream, onerror

    # setup new meeting room
    @setup = (roomid) !->
      captureUserMedia !->
        !signaler && initSignaler!
        signaler.broadcast {roomid}

    # join pre-created meeting room
    @meet = (room) !->
      captureUserMedia !->
        !signaler && initSignaler!
        signaler.join {to: room.userid, room.roomid}

    # check pre-created meeting rooms
    @check = initSignaler


  # it is a backbone object
  Signaler = (root) !->
    # unique identifier for the current user
    userid = root.userid || getToken!

    # self instance
    signaler = @

    # object to store all connected peers
    peers = {}

    # object to store all connected participants's ids
    participants = {}

    # it is called when your signaling implementation fires "onmessage"
    @onmessage = (message) !->
      # if new room detected
      if message.roomid and message.broadcasting and not signaler.sentParticipationRequest
        root.onmeeting message

      # if someone shared SDP
      if message.sdp and message.to ~= userid
        @onsdp message

      # if someone shared ICE
      if message.candidate and message.to ~= userid
        @onice message

      # if someone sent participation request
      if message.participationRequest and message.to ~= userid
        participationRequest message.userid

      # session initiator transmitted new participant's details
      # it is useful for multi-user connectivity
      if message.conferencing and message.newcomer !~= userid and !!participants[message.newcomer] ~= false
        participants[message.newcomer] = message.newcomer
        root.stream && signaler.signal {
          participationRequest: true
          to: message.newcomer
        }

    participationRequest = (_userid) !->
      # it is appeared that 10 or more users can send 
      # participation requests concurrently
      # onicecandidate fails in such case
      if not signaler.creatingOffer
        signaler.creatingOffer = true
        createOffer _userid
        setTimeout !->
          signaler.creatingOffer = false
          if signaler.participants and signaler.participants.length
            repeatedlyCreateOffer!
        , 1000
      else
        if not signaler.participants
          signaler.participants = []
        signaler.participants[signaler.participants.length] = _userid

    # reusable function to create new offer
    createOffer = (unto) !->
      _options = options
      _options.to = unto
      _options.stream = root.stream
      peers[unto] = Offer.createOffer _options

    # reusable function to create new offer repeatedly
    repeatedlyCreateOffer = !->
      firstParticipant = signaler.participants[0]
      
      if !firstParticipant then return

      signaler.creatingOffer = true
      createOffer firstParticipant

      # delete "firstParticipant" and swap array
      delete signaler.participants[0]
      signaler.participants = swap signaler.participants

      setTimeout !->
        signaler.creatingOffer = false
        if signaler.participants[0]
          repeatedlyCreateOffer!
      , 1000

    # if someone shared SDP
    @onsdp = (message) !->
      sdp = message.sdp

      if sdp.type is \offer
        _options = options
        _options.stream = root.stream
        _options.sdp = sdp
        _options.to = message.userid
        peers[message.userid] = Answer.createAnswer _options

      if sdp.type is \answer
        peers[message.userid].setRemoteDescription sdp

    # if someone shared ICE
    @onice = (message) !->
      peer = peers[message.userid]
      if peer
        peer.addIceCandidate message.candidate

    # it is passed over Offer/Answer objects for reusability
    options = 
      onsdp: (sdp, to) !-> signaler.signal {sdp, to},

      onicecandidate: (candidate, to) !-> signaler.signal {candidate, to},

      onaddstream: (stream, _userid) ->
        
        stream.onended = !-> if root.onuserleft then root.onuserleft _userid

        video = document.createElement \video
        video.id = _userid
        video[if isFirefox then \mozSrcObject else \src] = if isFirefox then stream else window.webkitURL.createObjectURL stream
        video.autoplay = true
        video.controls = false
        video.play!

        onRemoteStreamStartsFlowing = !->
          if not (video.readyState <= HTMLMediaElement.HAVE_CURRENT_DATA or video.paused or video.currentTime <= 0)
            then afterRemoteStreamStartedFlowing!
            else setTimeout onRemoteStreamStartsFlowing, 300

        afterRemoteStreamStartedFlowing = !->
          # for video conferencing
          signaler.isbroadcaster && signaler.signal {conferencing: true, newcomer: _userid}

          root.onaddstream? {video, stream, userid: _userid, type: \remote}

        onRemoteStreamStartsFlowing!

    # call only for session initiator
    @broadcast = (_config) !->
      signaler.roomid = _config.roomid || getToken!
      signaler.isbroadcaster = true

      do transmit = !->
        signaler.signal {signaler.roomid, broadcasting: true}

        if not signaler.stopBroadcasting and not root.transmitOnce
          setTimeout transmit, 3000

    # called for each new participant
    @join = (_config) !->
      signaler.roomid = _config.roomid
      @signal {_config.to, participationRequest: true}
      signaler.sentParticipationRequest = true

    window.onbeforeunload = !-> leaveRoom!

    leaveRoom = !->
      signaler.signal {leaving: true}

      # stop broadcasting room
      if signaler.isbroadcaster then signaler.stopBroadcasting = true

      # leave user media resources
      root.stream?.stop!

    root.leave = leaveRoom

    socket = null

    socket = root.openSignalingChannel (message) !->
      message = JSON.parse message
      console.log '< ', message
      if message.userid !~= userid
        if not message.leaving
          signaler.onmessage message
        else if root.onuserleft
          root.onuserleft message.userid

    # method to signal the data
    @signal = (data) !->
      console.log '> ', data
      data.userid = userid
      socket.send JSON.stringify data

  # reusable stuff
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

  optionalArgument = {optional: [{DtlsSrtpKeyAgreement: true}]}

  offerAnswerConstraints =
    optional: []
    mandatory:
      OfferToReceiveAudio: true
      OfferToReceiveVideo: true

  getToken = -> (Math.round Math.random! * 9999999999) + 9999999999
  
  onSdpSuccess = ->

  onSdpError = !->
    console.error 'sdp error:', it.name, it.message

  # var offer = Offer.createOffer(config);
  # offer.setRemoteDescription(sdp);
  # offer.addIceCandidate(candidate);
  Offer =
    createOffer: (config) ->
      peer = new RTCPeerConnection iceServers, optionalArgument

      if config.stream then peer.addStream config.stream

      if config.onaddstream
        peer.onaddstream = (event) !->
          config.onaddstream event.stream, config.to

      peer.onicecandidate = (event) !->
        if !event.candidate then sdpCallback!

      peer.ongatheringchange = (event) !->
        if event.currentTarget && event.currentTarget.iceGatheringState is \complete
          sdpCallback!

      peer.createOffer (sdp) !->
        peer.setLocalDescription sdp
        if isFirefox then config.onsdp sdp, config.to
      , onSdpError, offerAnswerConstraints

      sdpCallback = !-> config.onsdp peer.localDescription, config.to

      @peer = peer

      @

    setRemoteDescription: (sdp) !->
      @peer.setRemoteDescription new RTCSessionDescription sdp, onSdpSuccess, onSdpError

    addIceCandidate: (candidate) !->
      @peer.addIceCandidate new RTCIceCandidate {candidate.sdpMLineIndex, candidate.candidate}

  # var answer = Answer.createAnswer(config);
  # answer.setRemoteDescription(sdp);
  # answer.addIceCandidate(candidate);
  Answer =
    createAnswer: (config) ->
      peer = new RTCPeerConnection iceServers, optionalArgument

      if config.stream then peer.addStream config.stream

      if config.onaddstream
        peer.onaddstream = (event) !->
          config.onaddstream event.stream, config.to
      
      peer.onicecandidate = (event) !->
        config.onicecandidate event.candidate, config.to

      peer.setRemoteDescription new RTCSessionDescription config.sdp, onSdpSuccess, onSdpError
      peer.createAnswer (sdp) !->
        peer.setLocalDescription sdp
        config.onsdp sdp, config.to
      , onSdpError, offerAnswerConstraints

      @peer = peer

      @

    addIceCandidate: (candidate) !->
      @peer.addIceCandidate new RTCIceCandidate {candidate.sdpMLineIndex, candidate.candidate}

  # swap arrays
  swap = (arr) ->
    swapped = []
    for e in arr
      if e? and e isnt true
        swapped.push i
    swapped