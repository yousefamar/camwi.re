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

    join: (roomid) !->
      @roomid = roomid
      self = @
      <-! @_captureUserMedia
      exists <-! self.sig.join roomid, _
      self.sig.is-host = not exists

    part: !->
      @sig.signal \part
      @stream?.stop!


  window.Signaler = (root) !->
    # unique identifier for the current user
    @userid = userid = getToken!

    @is-host = false

    # self instance
    self = @

    # object to store all connected peers
    peers = {}

    # object to store all connected participants's ids
    participants = {}

    @connect = !->
      socket = io.connect it

      @signal = (event, data) !->
        data = data || {}
        data.userid = @userid
        console.log '> ', event, data
        socket.emit event, data

      socket
        ..on \join, (userid) !->
          console.log '< ', \join, userid
          # it is appeared that 10 or more users can send 
          # participation requests concurrently
          # onicecandidate fails in such case
          if not self.creatingOffer
            self.creatingOffer = true
            createOffer userid
            setTimeout !->
              self.creatingOffer = false
              if self.participants and self.participants.length
                repeatedlyCreateOffer!
            , 1000
          else
            if not self.participants
              self.participants = []
            self.participants[self.participants.length] = userid
        
        ..on \part, (data) !->
          console.log '< ', \part, data
          root.onuserleft data.userid
          return

        ..on \sdp, (data) !->
          console.log '< ', \sdp, data
          if data.to ~= userid
            self.onsdp data

        ..on \ice, (data) !->
          console.log '< ', \ice, data
          if data.to ~= userid
            self.onice data

        ..on \new, (data) !->
          console.log '< ', \new, data
          if data.conferencing and data.newcomer !~= userid and !!participants[data.newcomer] ~= false
            participants[data.newcomer] = data.newcomer
            root.stream && self.signal \joinUsr, {to: data.newcomer}, ->

    # reusable function to create new offer
    createOffer = (unto) !->
      _options = options
      _options.to = unto
      _options.stream = root.stream
      peers[unto] = Offer.createOffer _options

    # reusable function to create new offer repeatedly
    repeatedlyCreateOffer = !->
      firstParticipant = self.participants[0]
      
      if !firstParticipant then return

      self.creatingOffer = true
      createOffer firstParticipant

      # delete "firstParticipant" and swap array
      delete self.participants[0]
      self.participants = swap self.participants

      setTimeout !->
        self.creatingOffer = false
        if self.participants[0]
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
      onsdp: (sdp, to) !-> self.signal \sdp, {sdp, to},

      onicecandidate: (candidate, to) !-> self.signal \ice, {candidate, to},

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
          self.is-host && self.signal \new {conferencing: true, newcomer: _userid}

          root.onaddstream? video

        onRemoteStreamStartsFlowing!

    # called for each new participant
    @join = (roomid, callback) !->
      @signal \join, {roomid}, callback
        

    @signal = !-> console.error 'No signalling function set!'