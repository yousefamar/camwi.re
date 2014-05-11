window.WCIO = {}

window.WCIO.main = do
  ->

    vc = new VideoChat!

    vc.onaddstream = !->
      document.body.appendChild it

    vc.onuserleft = !->
        video = document.getElementById it
        video && video.parentNode.removeChild video

    vc.sig.connect "http://amar.io:9980"

    roomID = (window.location.href.match /[^/]+$/g)?[0]
    if not roomID
      roomID := 'xxxxxx'.replace /[x]/g, -> (Math.random!*36.|.0).toString 36
      window.history.replaceState {}, "New Session ID", "/#{roomID}"

    console.log "Joining room #{roomID}"
    vc.join "webcamio-#{roomID}"