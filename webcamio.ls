window.WCIO = {}

window.WCIO.main = do
  ->

    vc = new VideoChat!

    in-vc = false

    vc.onmeeting = !->
      if not in-vc and it.roomid is "webcamio-#{roomID}"
        in-vc := true
        vc.join it.userid, it.roomID

    vc.onaddstream = !->
      document.body.appendChild it

    vc.onuserleft = !->
        video = document.getElementById it
        video && video.parentNode.removeChild video

    vc.sig.connect "http://amar.io:9980"

    roomID = (window.location.href.match /[^/]+$/g)?[0]
    if not roomID
      roomID := 'xxxxxx'.replace /[x]/g, -> (Math.random!*36.|.0).toString 36
      console.log "Creating at #{roomID}"
      in-vc := true
      vc.host "webcamio-#{roomID}"
      window.history.replaceState {}, "New Session ID", "/#{roomID}"
    else
      console.log "Connecting to #{roomID}"
      window.setTimeout ->
        if not in-vc
          console.log "Creating at #{roomID}"
          in-vc := true
          vc.host "webcamio-#{roomID}"
      , 3000