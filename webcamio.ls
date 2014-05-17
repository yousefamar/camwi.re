window.WCIO = {}

window.WCIO.main = do
  ->

    vc = new VideoChat!

    audioContext = new webkitAudioContext!
    thumbs = document.getElementById \thumbnails

    vc.onaddstream = (video, stream) !->
      source = audioContext.createMediaStreamSource stream
      analyser = audioContext.createAnalyser!
      source.connect analyser

      setInterval !->
        freqByteData = new Uint8Array analyser.frequencyBinCount
        analyser.getByteTimeDomainData freqByteData
        volume = (Math.max.apply(Math, freqByteData) - 128)/128
        video.className = if volume then \talking else ''
      , 100
      
      thumbs.appendChild video

    vc.onuserleft = !->
      video = document.getElementById it
      video && video.parentNode.removeChild video

    roomID = (window.location.href.match /[^/]+$/g)?[0]
    if not roomID
      roomID := 'xxxxxx'.replace /[x]/g, -> (Math.random!*36.|.0).toString 36
      window.history.replaceState {}, "New Room ID", "/#{roomID}"

    <-! vc.set-signaller new SignallerSocketIO vc
      .connect "http://amar.io:9980", _
    console.log "Joining room #{roomID}"
    vc.join "webcamio-#{roomID}"