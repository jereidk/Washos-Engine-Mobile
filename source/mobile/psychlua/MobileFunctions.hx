package mobile.psychlua;

import lime.ui.Haptic;
import psychlua.FunkinLua;

class MobileFunctions
{
	public static function implement(funk:FunkinLua)
	{
		#if LUA_ALLOWED
		var lua:State = funk.lua;

		#if mobile
		Lua_helper.add_callback(lua, "haptic", function(duration:Int, ?period:Int)
		{
			return Haptic.vibrate(period, duration);
		});

		Lua_helper.add_callback(lua, "touchUtilJustPressed", mobile.backend.TouchUtil.justPressed);
		Lua_helper.add_callback(lua, "touchUtilPressed", mobile.backend.TouchUtil.pressed);
		Lua_helper.add_callback(lua, "touchUtilJustReleased", mobile.backend.TouchUtil.justReleased);
		#end
		#end
	}
}