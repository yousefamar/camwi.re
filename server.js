var io = require('socket.io').listen(9980);

io.sockets.on('connection', function (socket) {
	socket.on('message', function (data) {
		socket.broadcast.emit('message', data);
	});
	socket.on('disconnect', function () {
		
	});
});