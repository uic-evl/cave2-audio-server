///////////////////////////////////////////////////////////////////////////////////
// 
//  OmegaLib and LYRA Cluster Sound Server for CAVE2 
//  at the Electronic Visualization Laboratory
//	University of Illinois at Chicago
//  Author:  JD Pirtle
//  2012
//
//////////////////////////////////////////////////////////////////////////////////

//create volume object
v = s.volume;

//set volume range
v.setVolumeRange(-90, 8);

(

//lyra ip
~rem = NetAddr("131.193.78.203", nil);

//local ip
~loc = NetAddr("127.0.0.1", nil);

//send to lyra
~lyra = NetAddr("131.193.78.203", 8000);

//send to processing
~proc = NetAddr("127.0.0.1", 12000);

//web app ip
thisProcess.openUDPPort(3131);
~app = NetAddr("127.0.0.1", 3131);

(
//start server
a = OSCFunc({ |msg, time, addr, recvPort|
	
	s.boot;
	~proc.sendMsg("server");	
	
}, '/startServer', ~rem).add;
);

(
//kill server
b = OSCFunc({ |msg, time, addr, recvPort|

	Server.all.do(_.freeAll);
	postln("All Buffers and Nodes freed");
	
}, '/killServer', ~rem).add;
);


/////////////////////////////////////////////////////////////////////////////////////////                             
//											 
//
//
//						////OMEGALIB SECTION/////
//
//												
//
/////////////////////////////////////////////////////////////////////////////////////////



///////////////////////OMEGALIB MULTICHANNEL ////////////////////////////////////////////

(
//load SynthDef on server
c = OSCFunc({ |msg, time, addr, recvPort|
	 
	//playback SynthDef
    SynthDef(\PlaySound, {| amp = 1.0, envDur, bufNum, xPos, yPos, zPos, xLPos, yLPos, zLPos, width, mix, roomSize, loop, attTime, susTime, relTime, susLevel |
	var env, source, subPos, numChan = 20, dist, postVol, preVol, volScale, pos, envTrig;
	
	
	xPos.poll(Impulse.kr(1), "xPos = ");
	zPos.poll(Impulse.kr(1), "zPos = ");
	xLPos.poll(Impulse.kr(1), "xLPos = ");
	zLPos.poll(Impulse.kr(1), "zLPos = ");
	
	//get angle of sound object from listener
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
	
	//envelope to fade in/out
	envTrig = HPZ1.kr(amp).abs > 0;
    amp = EnvGen.kr(Env([amp, amp], [envDur]), envTrig);
	
	//scale final amp 
	postVol = amp*volScale;
	
	//source
	source = PlayBuf.ar(1, bufNum, BufRateScale.kr(bufNum), 1, 0, loop: loop, doneAction:2);
	
	//add some reverb
	source = FreeVerb.ar(source, mix, roomSize, damp: 0.5, mul: 1, add: 0);
	
	//out for speakers
	Out.ar(0, PanAz.ar(numChan, source, pos, postVol, width, 0));
	
	//out for subs
	Out.ar(20, Pan2.ar(source, pos, postVol));Ê
	Ê Ê Ê Ê 
	}).add;
	postln("synth loaded");
					
}, '/loadSynth', ~rem).add;
);

(
//load buffer

d = OSCFunc({ |msg, time, addr, recvPort|
	var bufNum, path;
	
	bufNum = msg[1];
	path = msg[2];
	s.sendMsg("b_allocRead", bufNum, path);
	postln("buffer loaded");

}, '/loadBuffer', ~rem).add;
);

(
//create new instance of mono synth

e = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, bufNum, amp, xPos, yPos, zPos, xLPos, yLPos, zLPos, width, mix, roomSize, loop, attTime, susTime, relTime, susLevel;
	
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
	attTime = msg[14];
	susTime = msg[15];
	relTime = msg[16];
	susLevel = msg[17];
	
	~lyra.sendMsg("newMonoSound", nodeID, bufNum, amp, xPos, zPos);
	
	s.sendMsg("s_new", "PlaySound", nodeID, 0, 0, \bufNum, bufNum, \amp, amp, \xPos, xPos, \yPos, yPos, \zPos, zPos, \xLPos, xLPos, \yLPos, yLPos, \zLPos, zLPos, \width, width, \mix, mix, \roomSize, roomSize, \loop, loop, \attTime, attTime, \susTime, susTime, \relTime, relTime, \susLevel, susLevel);
		
}, '/play', ~rem).add;
);


(
//change volume of synth instance

f = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, amp;
	
	nodeID = msg[1];
	amp = msg[2];
	s.sendMsg("n_set", nodeID, \amp, amp);

	postln("setVol!!");
		
}, '/setVol', ~rem).add;
);

(
//fade in/out synth instance

~envFunc = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, amp, envDur;
	
	nodeID = msg[1];
	amp = msg[2];
	envDur = msg[3];
	s.sendMsg("n_set", nodeID, \amp, amp, \envDur, envDur);
		
}, '/setVolEnv', ~rem).add;
);

(
//update location of sound object

g = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, xPos, yPos, zPos;
	
	nodeID = msg[1];
	xPos = msg[2];
	yPos = msg[3];
	zPos = msg[4];
	s.sendMsg("n_set", nodeID, \xPos, xPos, \yPos, yPos, \zPos, zPos);
		
}, '/setObjectLoc', ~rem).add;
);

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

(
//update location of listener

h = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, xLPos, yLPos, zLPos;
	
	nodeID = msg[1];
	xLPos = msg[2];
	yLPos = msg[3];
	zLPos = msg[4];
	s.sendMsg("n_set", nodeID, \xLPos, xLPos, \yLPos, yLPos, \zLPos, zLPos);
		
}, '/setListLoc', ~rem).add;
);


///////////////////OMEGALIB STEREO SOURCES//////////////////////////////////////

(
//load SynthDef on server
r = OSCFunc({ |msg, time, addr, recvPort|

 SynthDef(\playStereo, {| bufNum, amp, loop |   
	 var sourceR, sourceL, source;
	 
	 //source is a stereo file
	 source = PlayBuf.ar(2, bufNum, BufRateScale.kr(bufNum), 1, 0, loop: loop, doneAction:2);
	 
	 amp = amp.linlin(0.0, 1.0, 0.0, 1.0, clip: \minmax);
	  
	 source = source*amp;
	 
	 //strip left and right
	 sourceR = source[1];
	 sourceL = source[0];
	
	 Out.ar([6, 7, 20], sourceL);
	 Out.ar([13, 14, 21], sourceR);
	 Ê Ê Ê Ê 
	}).add;
	
	postln("stereo synth loaded");
	
}, '/loadStereoSynth', ~rem).add;
);


(
//create new instance of stereo synth

t = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID, bufNum, amp, loop;
	
	nodeID = msg[1];
	bufNum = msg[2];
	amp = msg[3];
	loop = msg[4];
	
	~lyra.sendMsg("newStereoSound", nodeID, bufNum, amp);
	
	s.sendMsg("s_new", "playStereo", nodeID, 0, 0, \bufNum, bufNum, \amp, amp, \loop, loop);
	postln("new stereo synth !!");	
}, '/playStereo', ~rem).add;
);


(
//free node

i = OSCFunc({ |msg, time, addr, recvPort|
	var nodeID;
	
	nodeID = msg[1];
	s.sendMsg("n_free", nodeID);
	postln("node freed");	
}, '/freeNode', ~rem).add;
);

(
//free individual buffer

j = OSCFunc({ |msg, time, addr, recvPort|
	var bufNum;
	
	
	s.sendMsg("b_free", bufNum);
	postln("buffer freed");
		
}, '/freeBuf', ~rem).add;
);


/////////////////////////////// Server Volume and Mute Control ///////////////////////////////////

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


(
//mute

l = OSCFunc({ |msg, time, addr, recvPort|

	v.mute;
		
	postln("MUTE!!");
		
}, '/mute');
);

(
//unmute

m = OSCFunc({ |msg, time, addr, recvPort|

	v.unmute;
	
	postln("UNMUTE!!");
		
}, '/unMute');
);


////////////////////////// Playback for LYRA ////////////////////////////////////

// Synthdef for LYRA Playback

( 
SynthDef(\PlayLyra, {| amp = 0.0 |   
	 var sourceR, sourceL;
	 
	 sourceL = SoundIn.ar(2, 1, amp);
	 sourceR = SoundIn.ar(3, 1, amp);
	 
	 Out.ar([6, 7, 20], sourceL);
	 Out.ar([13, 14, 21], sourceR);
	 Ê Ê Ê Ê 
	}).add;
);	
 
	
(
// Start LYRA Playback

n = OSCFunc({ |msg, time, addr, recvPort|

	x = Synth.new("PlayLyra");

	postln("!! LYRA AUDIO LOADED !!");
		
}, '/playLyraStereo');
);

(
// Start LYRA Playback (from localhost)

w = OSCFunc({ |msg, time, addr, recvPort|

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

	
////////////////////////// MIC ROUTING ////////////////////////////////////////////

// Synthdef for Mic Routing

(
    SynthDef(\micRoute, {| amp = 0.0 |   
	 var mic1, mic2;
	 
	 mic1 = SoundIn.ar(0, 1, amp);
	 mic2 = SoundIn.ar(1, 1, amp);
	 
	 Out.ar(24, mic1);
	 Out.ar(25, mic2);
	 Ê Ê Ê Ê 
	}).add;
);

(
// Start Mic Routing

p = OSCFunc({ |msg, time, addr, recvPort|

	z = Synth.new("micRoute");
	
	postln("!! MICS ON !!");
		
}, '/routeMics');
);

(
// Stop Mic Routing

q = OSCFunc({ |msg, time, addr, recvPort|

	z.free;
	
	postln("!! MICS OFF !!");
		
}, '/killMics');
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

////////////////////////// Laptop Support ////////////////////////////////////

// Synthdef for Laptop-->Speaker routing

( 
	SynthDef(\Laptops, {| amp = 0.0 |   
	 var sourceR, sourceL;
	 
	 sourceR = SoundIn.ar(11, 1, amp);
	 sourceL = SoundIn.ar(12, 1, amp);
	 
	 Out.ar([6, 7, 20], sourceL);
	 Out.ar([13, 14, 21], sourceR);
	 Ê Ê Ê Ê 
	}).add;
);	
 

(
// Start Laptop Playback (from localhost)

~startmics = OSCFunc({ |msg, time, addr, recvPort|

	~lap = Synth.new("Laptops");

	postln("!! LAPTOP CONNECTED !!");
		
}, '/playlaptop');
);


(
// Stop Laptop Playback Local

~stopMics = OSCFunc({ |msg, time, addr, recvPort|

	~lap.free;
	
	postln("!! LAPTOP DISCONNECTED !!");
		
}, '/stopLaptop');
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
	 
	 Out.ar(13, rt);
	 Out.ar(7, lt);
	 Out.ar(15, rs);
	 Out.ar(5, ls);
	 Out.ar(18, rb);
	 Out.ar(2, lb);
	 Out.ar(10, ct);
	 Out.ar(20, sb);
	 Ê Ê Ê Ê 
	}).add;
);

(
// Start 7.1 Playback 

~playSevenOne = OSCFunc({ |msg, time, addr, recvPort|

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
	
	//get angle of sound object from listener
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
	Out.ar(20, Pan2.ar(source, pos, postVol));Ê
	Ê Ê 
}).add;
);



////////////////////////////////////////////////////////////////////////////////////

postln("        ");
postln("        ");
postln("        ");
postln(" +++++++++++ !!! CAVE2 AUDIO SERVER IS LOADED !!! +++++++++++ ");
postln("        ");
postln("        ");
postln("        ");


/////////////////////////////////////////////////////////////////////////////////


)


