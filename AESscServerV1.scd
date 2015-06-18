/////////////////////////////////////////////////////////////////////
// 											                       //
//  	OmegaLib Desktop Sound Server for CAVE2                     //
//  	at the Electronic Visualization Laboratory                 //
//		University of Illinois at Chicago                          //
//  	Author:  JD Pirtle						                   //
//  	2012-2015                                                  //
//                                                                 //
/////////////////////////////////////////////////////////////////////
(

var nChannels = 20; // CAVE2 = 20
var radius = 3.4; // CAVE2 = 3.4

// This specifies the base directory of all sounds
// Note: make sure the path ends with a '/'
var soundPath = "/Users/evldemo/sounds/";

var initialVolume = -9; // CAVE2 = -15, desktop = 0

var masterNodeIP = "131.193.78.203";
var statusDisplayIP = "131.193.78.203"; // Processing Status Display
var statusDisplayIP2 = "131.193.77.108"; // Processing Status Display
var webAppIP = "127.0.0.1"; // Web app

var stereoLeftChannels = [6,7,20]; // CAVE2 = [6,7,20]
var stereoRightChannels = [13,14,21]; // CAVE2 = [13,14,21]
var firstSpeakerChannel = 0; // CAVE2 = 0 (speakers 0-19)
var firstSubChannel = 20; // CAVE2 = 20 (subs 20-21)

// Set server sample rate
s.options.sampleRate= 48000;

//create volume object
v = s.volume;

//set volume range
v.setVolumeRange(-90, 8);

//set initial volume to lower range
v.volume_(initialVolume);

//master ip
~rem = NetAddr(masterNodeIP, nil);

//local ip
~loc = NetAddr("127.0.0.1", nil);

//send to lyra for processing app
~lyra = NetAddr(statusDisplayIP, 8000);
~status2 = NetAddr(statusDisplayIP2, 8000);

//send to lyra (omicron)
~omi = NetAddr(masterNodeIP, 12000);

//web app ip
thisProcess.openUDPPort(3131);
~app = NetAddr(webAppIP, 3131);

///////////////////////////////////////////////////////////////////////////////
(
//start server
a = OSCFunc({ |msg, time, addr, recvPort|

	s.boot;
	~omi.sendMsg("server started");

	~status.sendMgs("soundServerStarted");
	~status2.sendMgs("soundServerStarted");

}, '/startServer', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//kill server
b = OSCFunc({ |msg, time, addr, recvPort|

	Server.all.do(_.freeAll);
	~omi.sendMsg("server killed");
	postln("All Buffers and Nodes freed");

}, '/killServer', ~rem).add;
);


/////////////////////////////////////////////////////////////////////////////////
///////////////////////OMEGALIB MULTICHANNEL ////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
(
//load SynthDef on server
c = OSCFunc({ |msg, time, addr, recvPort|

	//playback SynthDef
	SynthDef(\PlaySound, {| amp = 1.0, envDur, bufNum, xPos, yPos, zPos, xLPos, yLPos, zLPos, xUser, yUser, zUser, pos, vol, width, mix, roomSize, loop, playRate = 1, trigger = 0, startFrame = 0 |
		var env, source, subPos, numChan = nChannels, dist, postVol, preVol, volScale, envTrig;


		//xPos.poll(Impulse.kr(1), "xPos = ");
		//zPos.poll(Impulse.kr(1), "zPos = ");
		//xLPos.poll(Impulse.kr(1), "xLPos = ");
		//zLPos.poll(Impulse.kr(1), "zLPos = ");
		//xUser.poll(Impulse.kr(1), "xUser = ");
		//zUser.poll(Impulse.kr(1), "zUser = ");
		//vol.poll(Impulse.kr(1), "vol = ");
		//pos.poll(Impulse.kr(1), "pos = ");
		//width.poll(Impulse.kr(1), "width = ");
		OSCFunc.trace(true);

		//get distance (radius) of object from listener
		//dist = hypot((xPos-xUser), (zPos-zUser));
		//dist.poll(Impulse.kr(1), "dist = ");

		//use inverse distance law to scale volume
		//	preVol = vol;
		//preVol.poll(Impulse.kr(1), "preVol = ");

		//clamp preVol to range of 0.0-1.0
		//volScale is used as a multplier to modify
		//amp, which is the initial volume scale per sound object
		volScale = vol.linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax);
		//volScale.poll(Impulse.kr(1), "volScale = ");

		//envelope to fade in/out
		envTrig = HPZ1.kr(amp).abs > 0;
		amp = EnvGen.kr(Env([amp, amp], [envDur]), envTrig);

		//scale final amp
		postVol = amp*volScale;

		//source
		source = PlayBuf.ar(1, bufNum, playRate, trigger, startFrame, loop: loop, doneAction:2);

		//add some reverb
		source = FreeVerb.ar(source, mix, roomSize, damp: 0.5, mul: 1, add: 0);

		//out for speakers
		Out.ar(firstSpeakerChannel, PanAz.ar(numChan, source, pos, postVol, width, 0));

		//out for subs
		Out.ar(firstSubChannel, Pan2.ar(source, pos, postVol));
	}).add;
	//postln("synth loaded");

}, '/loadSynth', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//load buffer
d = OSCFunc({ |msg, time, addr, recvPort|
	var bufNum, fileName, path;

	bufNum = msg[1];
	fileName = msg[2];
	path = soundPath ++ fileName;
	s.sendMsg("b_allocRead", bufNum, path);
	postln("buffer loaded");

	~omi.sendMsg("buffer " + bufNum + " loaded");

}, '/loadBuffer', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//create new instance of mono synth
e = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, bufNum, amp, xPos, yPos, zPos, xLPos, yLPos, zLPos, xUser, yUser, zUser, vol, pos, width, mix, roomSize, loop, playRate, trigger, startFrame;

	nodeID = msg[1];
	bufNum = msg[2];
	amp = msg[3];
	xPos = msg[4];
	yPos = msg[5];
	zPos = msg[6];
	xLPos = msg[7];
	yLPos = msg[8];
	zLPos = msg[9];
	width = msg[10];
	mix = msg[11];
	roomSize = msg[12];
	loop = msg[13];
	playRate = msg[14];
	trigger = msg[15];
	startFrame = msg[16];
	xUser = msg[17];
	yUser = msg[18];
	zUser = msg[19];
	vol = msg[20];
	pos = msg[21];

	postln("buffer = " + bufNum + " | " + "node = " + nodeID);

	~lyra.sendMsg("newMonoSound", nodeID, bufNum, amp, xPos, zPos);

	s.sendMsg("s_new", "PlaySound", nodeID, 0, 0, \bufNum, bufNum, \amp, amp, \xPos, xPos, \yPos, yPos, \zPos, zPos, \xLPos, xLPos, \yLPos, yLPos, \zLPos, zLPos, \width, width, \mix, mix, \roomSize, roomSize, \loop, loop, \playRate, playRate, \trigger, trigger, \startFrame, startFrame, \xUser, xUser, \yUser, yUser, \zUser, zUser, \vol, vol, \pos, pos);

}, '/play', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//change volume of synth instance
f = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, amp;

	nodeID = msg[1];
	amp = msg[2];
	s.sendMsg("n_set", nodeID, \amp, amp);

	//postln("setVol!!");

}, '/setVol', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//fade in/out MONO synth instance
~envFunc = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, amp, envDur;

	nodeID = msg[1];
	amp = msg[2];
	envDur = msg[3];
	s.sendMsg("n_set", nodeID, \amp, amp, \envDur, envDur);

	postln("fade");
}, '/setVolEnv', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//update location of sound object
g = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, xPos, yPos, zPos;

	nodeID = msg[1];
	xPos = msg[2];
	yPos = msg[3];
	zPos = msg[4];
	s.sendMsg("n_set", nodeID, \xPos, xPos, \yPos, yPos, \zPos, zPos);
	//postln("setObjectPos!!");
}, '/setObjectLoc', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//update location of user
u = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, xUser, yUser, zUser;

	nodeID = msg[1];
	xUser = msg[2];
	yUser = msg[3];
	zUser = msg[4];
	s.sendMsg("n_set", nodeID, \xUser, xUser, \yUser, yUser, \zUser, zUser);
	//postln("setUserPos!!");
}, '/setUserLoc', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//update reverb on sound object
~verb = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, mix, roomSize;

	nodeID = msg[1];
	mix = msg[2];
	roomSize = msg[3];
	s.sendMsg("n_set", nodeID, \mix, mix, \roomSize, roomSize);

}, '/setReverb', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//update location of listener
h = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, xLPos, yLPos, zLPos;

	nodeID = msg[1];
	xLPos = msg[2];
	yLPos = msg[3];
	zLPos = msg[4];
	s.sendMsg("n_set", nodeID, \xLPos, xLPos, \yLPos, yLPos, \zLPos, zLPos);
	//postln("setListPos!!");
}, '/setListLoc', ~rem).add;
);
///////////////////////////////////////////////////////////////////////////////
(
//update volume of sound instance relative to user
n = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, vol;

	nodeID = msg[1];
	vol = msg[2];
	s.sendMsg("n_set", nodeID, \vol, vol);
	//postln("setVol!!");
}, '/setVol', ~rem).add;
);
///////////////////////////////////////////////////////
(
//update speaker angle
n = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, pos;

	nodeID = msg[1];
	pos = msg[2];
	s.sendMsg("n_set", nodeID, \pos, pos);
	//postln("setPos!!");
}, '/setPos', ~rem).add;
);
///////////////////////////////////////////////////////
(
//update sound object width
n = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, width;

	nodeID = msg[1];
	width = msg[2];
	s.sendMsg("n_set", nodeID, \width, width);
	//postln("setWidth!!");
}, '/setWidth', ~rem).add;
);
///////////////////////////////////////////////////////
(
//update frame being played back
// '0' is the beginning of a file

~setMonoFrame = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, trigger, startFrame;

	nodeID = msg[1];
	trigger = 1;
	startFrame = msg[3];

	s.sendMsg("n_set", nodeID, \trigger, trigger, \startFrame, startFrame);

}, '/setMonoFrame', ~rem).add;
);


(
//update playback rate
// 1.0 is the server's sample rate, 2.0 is one octave up, 0.5 is one octave down
// -1.0 is backwards normal rate

~setMonoRate = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, playRate;

	nodeID = msg[1];
	playRate = msg[2];

	s.sendMsg("n_set", nodeID, \playRate, playRate);

}, '/setMonoRate', ~rem).add;
);

/////////////////////////////////////////////////////////////////////////////////
///////////////////OMEGALIB STEREO SOURCES///////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
(
//load SynthDef on server
r = OSCFunc({ |msg, time, addr, recvPort|

	SynthDef(\playStereo, {| bufNum, amp, loop, envDur, playRate = 1, trigger = 0, startFrame = 0  |
		var sourceR, sourceL, source, envTrig;

		//source is a stereo file
		source = PlayBuf.ar(2, bufNum, playRate, trigger, startFrame, loop: loop, doneAction:2);

		amp = amp.linlin(0.0, 1.0, 0.0, 1.0, clip: \minmax);

		//envelope to fade in/out
		envTrig = HPZ1.kr(amp).abs > 0;
		amp = EnvGen.kr(Env([amp, amp], [envDur]), envTrig);

		source = source*amp;

		//strip left and right
		sourceR = source[1];
		sourceL = source[0];

		Out.ar(stereoLeftChannels, sourceL);
		Out.ar(stereoRightChannels, sourceR);
		� � � �
	}).add;

	postln("stereo synth loaded");

}, '/loadStereoSynth', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//create new instance of stereo synth

t = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, bufNum, amp, loop, playRate, trigger, startFrame, rateRatio;

	nodeID = msg[1];
	bufNum = msg[2];
	amp = msg[3];
	loop = msg[4];
	playRate = msg[5];
	trigger = msg[6];
	startFrame = msg[7];

	~lyra.sendMsg("newStereoSound", nodeID, bufNum, amp);

	s.sendMsg("s_new", "playStereo", nodeID, 0, 0, \bufNum, bufNum, \amp, amp, \loop, loop, \playRate, playRate, \trigger, trigger, \startFrame, startFrame);
	postln("new stereo synth !!");
}, '/playStereo', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//fade in/out STEREO synth instance

~envStereo = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, amp, envDur;

	nodeID = msg[1];
	amp = msg[2];
	envDur = msg[3];
	s.sendMsg("n_set", nodeID, \amp, amp, \envDur, envDur);

}, '/setSterVolEnv', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//free node

i = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID;

	nodeID = msg[1];
	s.sendMsg("n_free", nodeID);
	postln("node freed");
}, '/freeNode', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//free individual buffer
j = OSCFunc({ |msg, time, addr, recvPort|
	var bufNum;


	s.sendMsg("b_free", bufNum);
	postln("buffer freed");

}, '/freeBuf', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//update frame being played back
// '0' is the beginning of a file

~setStereoFrame = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, trigger, startFrame;

	nodeID = msg[1];
	trigger = 1;
	startFrame = msg[3];

	s.sendMsg("n_set", nodeID, \trigger, trigger, \startFrame, startFrame);

}, '/setStereoFrame', ~rem).add;
);

///////////////////////////////////////////////////////////////////////////////
(
//update playback rate
// 1.0 is the server's sample rate, 2.0 is one octave up, 0.5 is one octave down
// -1.0 is backwards normal rate

~setStereoRate = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, trigger, playRate;

	nodeID = msg[1];
	playRate = msg[2];

	s.sendMsg("n_set", nodeID, \playRate, playRate);

}, '/setStereoRate', ~rem).add;
);

/////////////////////////////////////////////////////////////////////////////////
////////////////////////Server Volume and Mute Control //////////////////////////
/////////////////////////////////////////////////////////////////////////////////
(
//set volume

k = OSCFunc({ |msg, time, addr, recvPort|

	var amp;

	amp = msg[1];
	//remap range from 0.0 -- 1.0 to -30 -- 8
	//amp = amp.linlin(0.0, 1.0, -30, 8, clip: \minmax);
	v.volume = amp;

	postln("Volume is " + amp);


}, '/serverVol');
);

///////////////////////////////////////////////////////////////////////////////
(
//mute

l = OSCFunc({ |msg, time, addr, recvPort|

	v.mute;

	postln("MUTE!!");

}, '/mute');
);

///////////////////////////////////////////////////////////////////////////////
(
//unmute

m = OSCFunc({ |msg, time, addr, recvPort|

	v.unmute;

	postln("UNMUTE!!");

}, '/unMute');
);


/////////////////////////////////////////////////////////////////////////////////
////////////////////////// Playback for LYRA ////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////

// Synthdef for LYRA Playback

(
SynthDef(\PlayLyra, {| amp = 0.0 |
	var sourceR, sourceL;

	sourceL = SoundIn.ar(2, 1, amp);
	sourceR = SoundIn.ar(3, 1, amp);

	Out.ar(stereoLeftChannels, sourceL);
	Out.ar(stereoRightChannels, sourceR);

}).add;
);


(
// Start LYRA Playback

n = OSCFunc({ |msg, time, addr, recvPort|

	x.free;
	x = Synth.new("PlayLyra");

	postln("!! LYRA AUDIO LOADED !!");

}, '/playLyraStereo');
);

(
// Start LYRA Playback (from localhost)

w = OSCFunc({ |msg, time, addr, recvPort|

	x.free;
	x = Synth.new("PlayLyra");

	postln("!! LYRA AUDIO LOADED !!");

}, '/playLyraStereoLocal');
);

(
// Stop LYRA Playback

z = OSCFunc({ |msg, time, addr, recvPort|

	x.free;

	postln("!! STOP LYRA AUDIO !!");

}, '/stopLyraStereoLocal');
);

(
// Stop LYRA Playback Local

o = OSCFunc({ |msg, time, addr, recvPort|

	x.free;

	postln("!! STOP LYRA AUDIO !!");

}, '/stopLyraStereo');
);

/////////////////////////////////////////////////////////////////////////////////
////////////////////////// MIC ROUTING //////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////

// Synthdef for Mic Routing to CAVE2
(
SynthDef(\micLocal, {| amp = 0.0 |
	var mic;

	mic = SoundIn.ar(0, 1, amp);

	Out.ar(stereoLeftChannels, mic);
	Out.ar(stereoRightChannels, mic);

}).add;
);

(
// Start Mic-->CAVE2

~mics = OSCFunc({ |msg, time, addr, recvPort|
	~micOn.free;
	~micOn = Synth.new("micLocal");

	postln("!! LOCAL MICS ON !!");

}, '/routeLocalMics');
);

(
// Stop Mic-->CAVE2

~noMics = OSCFunc({ |msg, time, addr, recvPort|

	~micOn.free;

	postln("!! LOCAL MICS OFF !!");

}, '/killLocalMics');
);



////////////////////////// VTC Support ////////////////////////////////////

// Synthdef for Mic-->VTC
(
SynthDef(\micVTC, {| amp = 0.0 |
	var mic;

	mic = SoundIn.ar(0, 1, amp);

	Out.ar(22, mic);
	Out.ar(23, mic);

}).add;
);

// Synthdef for VTC-->Speaker routing
(
SynthDef(\localVTC, {| amp = 0.0 |
	var sourceR, sourceL;

	sourceR = SoundIn.ar(11, 1, amp);
	sourceL = SoundIn.ar(10, 1, amp);

	Out.ar(stereoLeftChannels, sourceL);
	Out.ar(stereoRightChannels, sourceR);

}).add;
);

(
// Start VTC

p = OSCFunc({ |msg, time, addr, recvPort|

	~micV.free;
	~local.free;

	~micV = Synth.new("micVTC");
	~local = Synth.new("localVTC");

	postln("!! VTC ON !!");

}, '/startVTC');
);

(
// Stop VTC

q = OSCFunc({ |msg, time, addr, recvPort|

	~micV.free;
	~local.free;

	postln("!! VTC OFF !!");

}, '/stopVTC');
);



///////////////////////////////////////////////////////////////////////
// 		7.1 Routing

(
SynthDef(\sevenOne, {| amp = 0.0 |
	var rt, lt, rs, ls, rb, lb, ct, sb;

	lt = SoundIn.ar(2, 1, amp);
	rt = SoundIn.ar(3, 1, amp);
	lb = SoundIn.ar(4, 1, amp);
	rb = SoundIn.ar(5, 1, amp);
	ls = SoundIn.ar(6, 1, amp);
	rs = SoundIn.ar(7, 1, amp);
	ct = SoundIn.ar(8, 1, amp);
	sb = SoundIn.ar(9, 1, amp);

	// 13 = rt; 7 = lt; 15 = rs; 5 = ls; 18= rb; 2 = lb; 10 = ct; 20 = sb
	Out.ar(13, rt);
	Out.ar(7, lt);
	Out.ar(15, rs);
	Out.ar(5, ls);
	Out.ar(18, rb);
	Out.ar(2, lb);
	Out.ar(10, ct);
	Out.ar(20, sb);

}).add;
);

(
// Start 7.1 Playback

~playSevenOne = OSCFunc({ |msg, time, addr, recvPort|

	~seven.free;
	~seven = Synth.new("sevenOne");

	postln("!! 7.1 CONNECTED !!");

}, '/sevenOne');
);


(
// Stop 7.1 Playback
~stopSevenOne = OSCFunc({ |msg, time, addr, recvPort|

	~seven.free;

	postln("!! 7.1 DISCONNECTED !!");

}, '/stopSevenOne');
);


// synthdef for real time sine tones
(
SynthDef(\playSine, {| freq, tone, amp, dur, xPos, yPos, zPos, xLPos, yLPos, zLPos, width, mix, roomSize |
	var source, attTime = (0.3*dur), relTime = (0.3*dur), env, envgen;
	var subPos, numChan = 20, dist, postVol, preVol, volScale, pos;

	xPos.poll(Impulse.kr(1), "xPos = ");
	zPos.poll(Impulse.kr(1), "zPos = ");
	xLPos.poll(Impulse.kr(1), "xLPos = ");
	zLPos.poll(Impulse.kr(1), "zLPos = ");

	//get angle of sound from listener
	pos = atan2((zPos-zLPos), (xPos-xLPos))/pi;
	pos.poll(Impulse.kr(1), "pos = ");

	//pos offset
	pos = pos - 0.5;

	//get distance (radius) of object from listener
	dist = hypot((xPos-xLPos), (zPos-zLPos));
	dist.poll(Impulse.kr(1), "dist = ");

	//use inverse distance law to scale volume
	preVol = 1/(dist);
	preVol.poll(Impulse.kr(1), "preVol = ");

	//clamp preVol to range of 0.0-1.0
	//volScale is used as a multplier to modify
	//amp, which is the initial volume scale per sound object
	volScale = preVol.linlin(0.0, 1.0, 0.3, 1.0, clip: \minmax);
	volScale.poll(Impulse.kr(1), "volScale = ");

	//envelope to control duration
	env = Env([0, amp, amp, 0], [attTime, dur-(attTime+relTime), relTime], 1);
	envgen = EnvGen.kr(env, doneAction: 2);

	//scale final amp
	postVol = amp*volScale;

	source = SinOsc.ar(freq);
	//add some reverb
	source = FreeVerb.ar(source, mix, roomSize, damp: 0.5, mul: 1, add: 0);

	//out for speakers
	Out.ar(0, PanAz.ar(numChan, source, pos, postVol, width, 0));

	//out for subs
	Out.ar(20, Pan2.ar(source, pos, postVol));

}).add;
);

////////////////////////////////////////////////////////////////////////////////////

//Startup sound

s.sendMsg("b_allocRead", 1000, "/Users/evldemo/sounds/jd/superfriends.wav");

(
// play superfriends startup

~startup = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, bufNum = 1000, amp, loop;

	nodeID = -1;
	bufNum = 1;
	amp = 0.5;
	loop = 0.0;

	s.sendMsg("s_new", "playStereo", nodeID, 0, 0, \bufNum, bufNum, \amp, amp, \loop, loop);

	postln("!! OmegaSound Working !!");

}, '/startup', ~rem);
);

////////////////////////////////////////////////////////////////////////////////////

postln("        ");
postln("        ");
postln("        ");
postln(" +++++ !!! AES AUDIO SERVER IS LOADED !!! +++++");
postln(" ++++ Supports Omegalib Version 6.2 and above ++++ ");
postln(" ++++ NO DECORRELATION ++++ ");
//postln(" ++++++++++ DEVELOPMENT BUILD 2014-4-28 ++++++++++ ");
postln("        ");
postln("        ");
postln("        ");
postln("  The file path '"+soundPath+"' will be pre-pended to all loaded sounds.");

/////////////////////////////////////////////////////////////////////////////////


)


