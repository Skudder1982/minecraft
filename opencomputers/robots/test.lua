local robot = require("robot");
local quarrySize = 11;
local timerEvent;

function placeQuarry()
	robot.up();
	robot.select(15);
	robot.placeDown();
	robot.up();
	robot.select(16);
	robot.placeDown();
end

function digQuarry()
	robot.select(16);
	robot.swingDown();
	robot.down();
	robot.select(15);
	robot.swingDown();
	robot.down();
end

function clearInv()
	for i = 1,14 do
	  robot.select(i);
	  robot.drop();
	end
end

function move()
	for i = 1,quarrySize do
		robot.back();
	end
end

function work(isFirstTime)
	if not isFirstTime then
		digQuarry();
		clearInv();
		move();
	end
	
	placeQuarry();
end

function timerCallback()
	work(true);
	os.sleep(10);
	work(false);
	os.sleep(10);
	digQuarry();
	clearInv();
end

function start()
--	work(true);
--	timerEvent = event.timer(15, timerCallback);

	work(true);
	os.sleep(10);
	work(false);
	os.sleep(10);
	digQuarry();
	clearInv();
end

start();