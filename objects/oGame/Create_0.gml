global.telemetry = new Telemetry("https://telemetry-php.ddev.site/");
global.telemetry.setLogFunction(show_debug_message);
global.telemetry.setOnOff(true);
exception_unhandled_handler(global.telemetry.sendException);
global.telemetry.sendMessage("GameStart");
global.telemetry.sendSystemInfo();
alarm[0] = 1;