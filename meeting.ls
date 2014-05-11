# 2013, Muaz Khan - https://github.com/muaz-khan
# MIT License     - https://www.webrtc-experiment.com/licence/
# Documentation   - https://github.com/muaz-khan/WebRTC-Experiment/tree/master/meeting
# Modified by Yousef Amar <yousef@amar.io> on 2014-05-09

do ->
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


  class window.VideoChat
    ->
      @sig = new Signaler @
      @roomid = getToken!

      self = @
      window.addEventListener \beforeunload, !-> self.part!

    onmeeting: ->

    onuserleft: ->

    _captureUserMedia: (callback) !->
      self = @

      constraints =
        audio: true
        video: true

      onstream = (stream) !->
        stream.onended = !->
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

        self.onaddstream video

        callback stream

      onerror = !-> console.error it

      navigator.getUserMedia constraints, onstream, onerror

    host: (roomid) !->
      @roomid = roomid
      self = @
      @_captureUserMedia !-> self.sig.host roomid

    join: (userid, roomid) !->
      @roomid = roomid
      self = @
      @_captureUserMedia !-> self.sig.join userid, roomid

    part: !->
      @sig.signal {leaving: true}
      if @sig.is-host then @sig.stopBroadcasting = true
      @stream?.stop!


  window.Signaler = (root) !->
    # unique identifier for the current user
    @userid = userid = getToken!

    @is-host = false

    # self instance
    signaler = @

    # object to store all connected peers
    peers = {}

    # object to store all connected participants's ids
    participants = {}

    @connect = !->
      socket = io.connect it

      @signal = !->
        it.userid = @userid
        console.log '> ', it
        socket.send JSON.stringify it

      sig = @
      socket.on \message, !->
        it = JSON.parse it
        console.log '< ', it
        sig.on-signal it

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
        
        stream.onended = !-> root.onuserleft _userid

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
          signaler.is-host && signaler.signal {conferencing: true, newcomer: _userid}

          root.onaddstream? video

        onRemoteStreamStartsFlowing!

    # call only for session initiator
    @host = (roomid) !->
      signaler.is-host = true

      do transmit = !->
        signaler.signal {roomid, broadcasting: true}

        if not signaler.stopBroadcasting and not root.transmitOnce
          setTimeout transmit, 3000

    # called for each new participant
    @join = (userid, roomid) !->
      @signal {to: userid, participationRequest: true}
      signaler.sentParticipationRequest = true

    @on-signal = (data) !->
      if data.leaving
        root.onuserleft data.userid
        return
      
      # if new room detected
      if data.roomid and data.broadcasting and not signaler.sentParticipationRequest
        root.onmeeting data

      # if someone shared SDP
      if data.sdp and data.to ~= userid
        @onsdp data

      # if someone shared ICE
      if data.candidate and data.to ~= userid
        @onice data

      # if someone sent participation request
      if data.participationRequest and data.to ~= userid
        participationRequest data.userid

      # session initiator transmitted new participant's details
      # it is useful for multi-user connectivity
      if data.conferencing and data.newcomer !~= userid and !!participants[data.newcomer] ~= false
        participants[data.newcomer] = data.newcomer
        root.stream && signaler.signal {
          participationRequest: true
          to: data.newcomer
        }
        

    @signal = !-> console.error 'No signalling function set!'