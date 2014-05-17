io = (require \socket.io).listen 9980

uid = 0
socks = {}
rooms = {}

io.sockets.on \connection, (socket) !->
  do
    uid := (uid + 1) % (Number.MAX_SAFE_INTEGER + 1)
  while socks[uid]?
  
  socket.uid = uid
  socks[uid] = socket

  socket.emit \uid, uid

  socket.on \sdp, (data) !->
    if data.to? and socks[data.to]?
      data.from = socket.uid
      socks[data.to].emit \sdp, data

  socket.on \ice, (data) !->
    if data.to? and socks[data.to]?
      data.from = socket.uid
      socks[data.to].emit \ice, data

  socket.on \new, (data) !->
    if data.to? and socks[data.to]? then socks[data.to].emit \join, data.new

  socket.on \join, (data, callback) !->
    if !data.roomid then return
    if data.roomid of rooms
      rooms[data.roomid].host.emit \join, socket.uid
      callback? true
    else
      rooms[data.roomid] = {host: socket}
      callback? false

  socket.on \part, (data) !->
    if data.to? and socks[data.to]? then socks[data.to].emit \part, socket.uid

  socket.on \disconnect, !->
    delete socks[socket.uid]