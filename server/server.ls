io = (require \socket.io).listen 9980
require! <[ http st ]>

http.create-server st path : process.cwd!, index : \index.html
  ..listen 8000

uid = 0
socks = {}
rooms = {}

part = (uid) !->
  if !sock = socks[uid] then return
  delete socks[uid]
  if sock.rid?
    delete rooms[sock.rid][uid]
    for uid-other of rooms[sock.rid] then if socks[uid-other]? then socks[uid-other].emit \part, uid
    for uid-other of rooms[sock.rid] then return
    delete rooms[sock.rid]

io.sockets.on \connection, (socket) !->
  do
    # NOTE: Node has no limit; Chrome does.
    #uid := (uid + 1) % (Number.MAX_SAFE_INTEGER + 1)
    uid++
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

  socket.on \join, (data) !->
    if !data.roomid then return
    for uid of rooms[data.roomid] then socks[uid]?.emit \join, socket.uid
    if data.roomid not of rooms then rooms[data.roomid] = {}
    socket.rid = data.roomid
    rooms[data.roomid][socket.uid] = socket

  socket.on \part, !-> part socket.uid

  socket.on \disconnect, !-> part socket.uid
