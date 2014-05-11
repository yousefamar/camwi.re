io = (require \socket.io).listen 9980

io.sockets.on \connection, (socket) !->
  socket.on \message, (data) !->
    socket.broadcast.emit \message, data
  socket.on \disconnect, !->