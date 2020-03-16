require! <[ http express socket.io ]>

app = express!
server = http.Server app
io = socket server

app.use '/' express.static \static

app.get '/*' (req, res) !-> res.send-file 'static/index.html' root: './'

uid = 0
socks = {}
rooms = {}

leave = (uid) !->
  if !sock = socks[uid] then return
  delete socks[uid]
  if sock.rid?
    delete rooms[sock.rid][uid]
    for uid-other of rooms[sock.rid] then if socks[uid-other]? then socks[uid-other].emit \leave, uid
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

  socket.on \leave, !-> leave socket.uid

  socket.on \disconnect, !-> leave socket.uid

server.listen (process.env.PORT || 8091)
