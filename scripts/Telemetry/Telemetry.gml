/**
 * Create one instance on game start
 */
function Telemetry(_url) constructor {
	
	url = _url;
	enabled = false;
	
	// todo: give each user a unique id?
	clientUid = undefined;

	// Enter a random 64 chracter long string here:
	//          "-------------------------------------------------" 
	apiSecret = "this is just an example you should replace it !!!";
	
	errorCount = 0;
	errorCountMax = 3;
	openRequests = ds_map_create();
	logFunc = undefined;
	
	/**
	 * Write your own function to log to a file
	 * or just use "show_debug_message"
	 */
	function setLogFunction(_function)
	{
		self.logFunc = _function;
		self.log("Changed log function");
	}
	
	/**
	 * Enable sending data once the user accepted!
	 */
	function setOnOff(_enable)
	{
		self.enabled = _enable;
	}
	
	/**
	 * Requirements for sending are met
	 */
	function sendingEnabled()
	{
		if (!self.enabled) {
			return false;
		}
		if (self.errorCount >= self.errorCountMax) {
			return false;
		}
		return true;
	}
	
	/**
	 * Logging for local debugging.
	 */
	function log(_msg)
	{
		if (is_undefined(self.logFunc)) {
			return;
		}
		self.logFunc(string(_msg));
	}
	
	/**
	 * Attach basic timestamps
	 */
	function setEventDefaults(_event)
	{
		_event[? "os_datetime"] = date_datetime_string(date_current_datetime());
		_event[? "game_time"] = current_time;
	}
	
	/**
	 * Send Information regarding the Operating System
	 * and detailed game information
	 * Needs only be send once, e.g. at game start for exceptions
	 */
	function sendSystemInfo()
	{
		if (!self.sendingEnabled()) {
			return;
		}
		
		var event = ds_map_create();
		event[? "name"] = "OS Info";
		self.setEventDefaults(event);
		
		var game = ds_map_create();
		game[? "build_datetime"] = date_datetime_string(GM_build_date);
		game[? "id"] = game_id;
		game[? "version"] = GM_version;
		game[? "runtime"] = GM_runtime_version;
		ds_map_add_map(event, "game", game);
		
		var os_map = os_get_info();
		if (os_map == -1) {
			os_map = ds_map_create();
		}
		os_map[? "language"] = os_get_language();
		os_map[? "region"] = os_get_region();
		os_map[? "os_version"] = os_version;
		ds_map_add_map(event, "os_info", os_map);
		
		
		self.sendEvent(event);
		ds_map_destroy(event);
	}
	
	
	/**
	 * Use this function with exception_unhandled_handler:
	 *   exception_unhandled_handler(global.telemetry.sendException);
	 */
	function sendException(_exception)
	{
		if (!self.sendingEnabled()) {
			return 0;
		}
		
		var event = ds_map_create();
		event[? "name"] = "Exception";
		self.setEventDefaults(event);
		event[? "message"] = _exception.message;
		event[? "longMessage"] = _exception.longMessage;
		event[? "script"] = _exception.script;
		event[? "stacktrace"] = _exception.stacktrace;
		self.sendEvent(event);
		ds_map_destroy(event);
		return 0;
	}
	
	/**
	 * Wrapper for a basic message Event
	 */
	function sendMessage(_msg)
	{
		if (!self.sendingEnabled()) {
			return;
		}
		var event = ds_map_create();
		self.setEventDefaults(event);
		event[? "name"] = "Message";
		event[? "message"] = string(_msg);
		self.sendEvent(event);
		ds_map_destroy(event);
	}
	
	/**
	 * Send an event to a remote server
	 * 
	 */
	function sendEvent(_event)
	{
		if (!self.sendingEnabled()) {
			return;
		}
		var name = _event[? "name"];
		if (is_undefined(name)) {
			self.log("sendEvent: Event requires at least a name attribute");
			return;
		}
		var encodedEvent = json_encode(_event);
		var hmac = self.hmacHash(encodedEvent, self.apiSecret);
		
		self.log("sendEvent: " + name  + " - " + encodedEvent);
		var requestId = http_post_string(self.url, "hmac=" + hmac + "&data=" + encodedEvent);
		self.openRequests[? requestId] = true;
	}
	
	/**
	 * Execute this function in a "Async - HTTP" Event.
	 * async_load is *only* available in the asynchronous Events, *but* then it's global!
	 */
	function checkAsync()
	{
		var requestId = async_load[? "id"];
		var idFound = undefined != self.openRequests[? requestId];
		if (idFound) {
			ds_map_delete(self.openRequests, requestId);
		} else {
			// Not one of our requests, we don't care for the result
			return;
		}

		self.log(json_encode(async_load));
		
		var status = async_load[? "status"];
		if (status < 0) {
			self.log("error requesting url: " + async_load[? "url"]);
			self.errorCount += 1;
			if (self.errorCount >= self.errorCountMax) {
				self.log("Maximum errors reached!");
			}
		} else {
			if (self.errorCount > 0) {
				self.errorCount = 0;
				self.log("Successful request reseted errors");
			}
		}
	}
	
	/**
	 * Calculate HMAC
	 *
	 * source: https://forum.yoyogames.com/index.php?threads/solved-sha512-hmac-script.31253/
	 */
	function hmacHash(_message, _key)
	{
		var block_size = 64; // for sha1: 512 bit / 8 
	    var msg_digest_size = 20;
	    var hexRef = "0123456789abcdef";
     
	    //Create buffers to hold our data. We use buffers rather than strings because
	    //0x00 - the NULL character in ASCII - typically terminates a string and may
	    //cause weirdness.
	    var buf_key = buffer_create(block_size, buffer_fixed, 1);
  
	    //64-bytes of padding and then enough room for the string
	    var buf_innerPad = buffer_create(block_size + string_length(_message), buffer_fixed, 1);
  
	    //NB - Using 84 here - SHA1 returns 20 bytes of data and we append that to
	    //64-bytes of padding
	    var buf_outerPad = buffer_create(block_size + msg_digest_size, buffer_fixed, 1);
  
	    if (string_length(_key) > block_size) {  
	        //If the key is longer than SHA1's block size, we hash the key and use
	        //that instead.
	        var sha = sha1_string_utf8(_key);
       
	        //Since SHA1 returns a hex *string*, we need to turn that into 8-bit bytes.
	        for( var n = 1; n <= 2 * msg_digest_size; n += 2 ) {
				var v = string_pos(string_char_at(sha, n+1), hexRef) + (string_pos(string_char_at(sha, n), hexRef) * 16) - 17;
				buffer_write(buf_key, buffer_u8, v);
			}
	    } else {
	        //If the key is smaller than SHA1's block size, just use the key. Since
	        //we're in a 64 byte buffer, it automatically pads with 0x00
	        buffer_write(buf_key, buffer_text, _key);
	    }
  
	    for( var n = 0; n < block_size; n++ ) {
	        var keyVal = buffer_peek(buf_key, n, buffer_u8);
       
	        //Bitwise XOR between the inner/outer padding and the key
	        buffer_poke( buf_innerPad, n, buffer_u8, $36 ^ keyVal );
	        buffer_poke( buf_outerPad, n, buffer_u8, $5C ^ keyVal );
	    }
  
	    //Seek to the end of the padding for both the inner and outer pads
	    buffer_seek(buf_innerPad, buffer_seek_start, block_size);
	    buffer_seek(buf_outerPad, buffer_seek_start, block_size);
  
	    //Append the string to encrypt
	    buffer_write(buf_innerPad, buffer_text, _message);
  
		//Apply SHA1 to (innerPad + string)
		var sha = buffer_sha1(buf_innerPad, 0, buffer_tell(buf_innerPad));	
		
		//Turn the SHA1 output into bytes and append this to the outer pad
		for( var n = 1; n <= 2 * msg_digest_size; n += 2 ) {
			var v = string_pos(string_char_at(sha, n+1), hexRef) + (string_pos(string_char_at(sha, n), hexRef) * 16) - 17;
			buffer_write(buf_outerPad, buffer_u8, v);
		}
		
	    var result = buffer_sha1(buf_outerPad, 0, buffer_tell(buf_outerPad));
	   
	    buffer_delete(buf_key);
	    buffer_delete(buf_innerPad);
	    buffer_delete(buf_outerPad);
  
	    return result;
	}
}
