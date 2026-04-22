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
		Lua_helper.add_callback(lua, "vibrate", function(duration:Int, ?period:Int = 0)
		{
			if (duration <= 0)
			{
				FunkinLua.luaTrace("vibrate: Invalid duration! Use seconds (ex: 0.5)", false, false, 0xFFFF0000);
				return;
			}
			Haptic.vibrate(period, Std.int(duration * 1000));
		});

		Lua_helper.add_callback(lua, "touchUtilJustPressed", TouchUtil.justPressed);
		Lua_helper.add_callback(lua, "touchUtilPressed", TouchUtil.pressed);
		Lua_helper.add_callback(lua, "touchUtilJustReleased", TouchUtil.justReleased);
		Lua_helper.add_callback(lua, "setHitboxVisible", function(visible:Bool = false):Void
		{
			PlayState.instance.hitbox.visible = visible;
		});
		Lua_helper.add_callback(lua, "enableKeyboard", function()
		{
			FlxG.stage.window.textInputEnabled = true;
		});
		#end
		#end
	}
}
