window.WCIO = {}

window.WCIO.main = do
  ->
    meeting = new Meeting

    in-meeting = false

    meeting.onmeeting = ->
      if not in-meeting and it.roomid is "webcamio-#{roomID}"
        in-meeting := true
        meeting.meet it

    meeting.onaddstream = ->
      document.body.appendChild it.video

    meeting.onuserleft = ->
        video = document.getElementById it
        video && video.parentNode.removeChild video

    meeting.openSignalingChannel = -> io.connect("http://amar.io:9980").on \message, it

    roomID = (window.location.href.match /[^/]+$/g)?[0]
    if not roomID
      roomID := 'xxxxxx'.replace /[x]/g, -> (Math.random!*36.|.0).toString 36
      console.log "Creating at #{roomID}"
      in-meeting := true
      meeting.setup "webcamio-#{roomID}"
      window.history.replaceState {}, "New Session ID", "/#{roomID}"
    else
      console.log "Connecting to #{roomID}"
      meeting.check "webcamio-#{roomID}"
      window.setTimeout ->
        if not in-meeting
          console.log "Creating at #{roomID}"
          in-meeting := true
          meeting.setup "webcamio-#{roomID}"
      , 3000