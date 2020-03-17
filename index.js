import PeerNetwork from './lib/p2p-peer.js';

const peerNet = new PeerNetwork();
let ownID, ownStream, roomID;
let largeVideo = null;

let addStream = (id, stream) => {
	let video = document.createElement('video');
	video.id          = id;
	video.srcObject   = stream;
	video.playsinline = true;
	video.autoplay    = true;
	video.controls    = false;
	video.muted       = id === ownID;
	video.onclick     = () => setLarge(video);
	let thumbs = document.getElementById('thumbnails');
	thumbs.appendChild(video);
	if (largeVideo === null && id !== ownID)
		setLarge(video);
	else
		video.play();
};

let setLarge = node => {
	if (largeVideo != null) {
		document.getElementById('thumbnails').appendChild(largeVideo);
		largeVideo.play();
	}
	largeVideo = node;
	document.body.prepend(largeVideo);
	largeVideo.play();
};

window.turnOnCam = () => {
	let camButton = document.getElementById('camButton');
	camButton.disabled = true;

	(async () => {
		try {
			ownStream = await navigator.mediaDevices.getUserMedia({
				audio: true,
				video: true,
			});
		} catch (e) {
			switch (e.name) {
				case 'PermissionDeniedError':
					window.alert("Camwi.re could not access your camera. Make sure you granted your browser permission to do so!");
					break;
				case 'NotFoundError':
					window.alert("Camwi.re could not detect any camera.");
					break;
				default:
					window.alert("Something went wrong: " + e.name);
					break;
			}
			camButton.disabled = false;
			return;
		}

		addStream(ownID, ownStream);

		peerNet.setStream(ownStream);

		camButton.parentNode.removeChild(camButton);

		document.getElementById('joinButton').disabled = false;
	})();
};

window.joinRoom = () => {
	let room = peerNet.join('re.camwi.' + roomID);
	room.eventEmitter.on('.', console.log);

	document.getElementById('startDialog').open = false;
};

window.addEventListener('DOMContentLoaded', async (event) => {
	roomID = window.location.pathname.substring(1);
	if (!roomID) {
		roomID = 'xxxxxx'.replace(/[x]/g, function(){
			return (Math.random() * 36 | 0).toString(36);
		});
		if (location.hostname === 'localhost')
			roomID = 'test';
		else
			window.history.replaceState({}, "New Room ID", "/" + roomID);
	}
	document.getElementById('roomID').innerText = roomID;

	await peerNet.connect('https://sig.amar.io');
	//await peerNet.connect('http://localhost:8090');

	peerNet.on('connection', peer => {
		console.log('Peer', peer.uid, 'connected');

		peer.on('greeting', msg => console.log('Peer', peer.uid + ':', msg));

		peer.on('disconnect', () => {});

		//console.log('Peer', peerNet.ownUID, '(us): Hi from', peerNet.ownUID + '!');

		//peer.send('greeting', 'Hi from ' + peerNet.ownUID + '!');

		addStream(peer.uid, peer.stream);
	});

	peerNet.on('disconnection', peer => {
		console.log('Peer', peer.uid, 'disconnected');
		var video = document.getElementById(peer.uid);
		if (video != null)
			video.parentNode.removeChild(video);
		if (video === largeVideo)
			largeVideo = null;
	});

	peerNet.on('uid', uid => {
		console.log('I got uid', uid);
		ownID = uid;
	});
});
