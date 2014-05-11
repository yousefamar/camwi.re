io = (require \socket.io).listen 9980

socks = {}
rooms = {}

io.sockets.on \connection, (socket) !->

  socket.on \leave, (data) !->
    socket.broadcast.emit \leave, data

  socket.on \sdp, (data) !->
    socket.broadcast.emit \sdp, data

  socket.on \ice, (data) !->
    socket.broadcast.emit \ice, data

  socket.on \new, (data) !->
    socket.broadcast.emit \new, data

  socket.on \joinUsr, (data, callback) !->
    if data.to? and socks[data.to]? then socks[data.to].emit \join, data.userid

  socket.on \join, (data, callback) !->
    if data.userid and !socks[data.userid]? then socks[data.userid] = socket

    if !data.roomid then return
    if data.roomid of rooms
      rooms[data.roomid].host.socket.emit \join, data.userid
      callback? true
    else
      rooms[data.roomid] = {host: {data.userid, socket}}
      callback? false

  socket.on \part, (data) !->
    socket.broadcast.emit \part, data

  socket.on \disconnect, !->