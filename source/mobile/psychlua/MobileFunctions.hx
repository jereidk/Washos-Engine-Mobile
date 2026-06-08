package mobile.psychlua;

import lime.ui.Haptic;
import psychlua.FunkinLua;
import psychlua.ModchartSprite;
import psychlua.LuaUtils;
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

		Lua_helper.add_callback(lua, "makeWallpaperSprite", function(tag:String, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.resetSpriteTag(tag);
			
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			
			#if android
			var base64String = androidmanager.os.Platform.getWallpaperBase64();
			if (base64String != null && base64String != "") 
			{
				try 
				{
					var bytes = haxe.crypto.Base64.decode(base64String);
					var image = lime.graphics.Image.fromBytes(bytes);
					var bmpData = openfl.display.BitmapData.fromImage(image);

					leSprite.loadGraphic(bmpData);

					var scaleX:Float = FlxG.width / leSprite.width;
					var scaleY:Float = FlxG.height / leSprite.height;
					var maxScale:Float = Math.max(scaleX, scaleY);

					leSprite.scale.set(maxScale, maxScale);
					leSprite.updateHitbox();
					leSprite.screenCenter();
				} 
				catch (e:Dynamic) 
				{
					FunkinLua.luaTrace("makeWallpaperSprite: Error converting wallpaper bytes!", false, false, 0xFFFF0000);
				}
			} 
			else 
			{
				FunkinLua.luaTrace("makeWallpaperSprite: Java returned an empty or null wallpaper.", false, false, 0xFFFF0000);
			}
			#end
			leSprite.antialiasing = backend.ClientPrefs.data.antialiasing;
			
			PlayState.instance.modchartSprites.set(tag, leSprite);
			leSprite.active = true;
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
