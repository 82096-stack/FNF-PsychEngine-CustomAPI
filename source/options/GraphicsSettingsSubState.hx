package options;

import objects.Character;
import backend.GraphicsAPI;
import backend.GraphicsAPIType;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var boyfriend:Character = null;
	public function new()
	{
		title = Language.getPhrase('graphics_menu', 'Graphics Settings');
		rpcTitle = 'Graphics Settings Menu';

		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		boyfriend.animation.finishCallback = function (name:String) boyfriend.dance();
		boyfriend.visible = false;

		var option:Option = new Option('Low Quality',
			'If checked, disables some background details,\ndecreases loading times and improves performance.',
			'lowQuality',
			BOOL);
		addOption(option);

		var option:Option = new Option('Anti-Aliasing',
			'If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals.',
			'antialiasing',
			BOOL);
		option.onChange = onChangeAntiAliasing;
		addOption(option);
		antialiasingOption = optionsArray.length-1;

		var option:Option = new Option('Shaders',
			"If unchecked, disables shaders.\nIt's used for some visual effects, and also CPU intensive for weaker PCs.",
			'shaders',
			BOOL);
		addOption(option);

		var option:Option = new Option('GPU Caching',
			"If checked, allows the GPU to be used for caching textures, decreasing RAM usage.\nDon't turn this on if you have a shitty Graphics Card.",
			'cacheOnGPU',
			BOOL);
		addOption(option);

		#if !html5
		var option:Option = new Option('V-Sync',
			'If checked, caps the framerate to your display refresh rate.\nIf unchecked, the framerate will be unlimited for maximum performance.',
			'vsync',
			BOOL);
		option.onChange = onChangeVSync;
		addOption(option);

		var option:Option = new Option('Graphics Rendering API',
			'Select which graphics rendering API to use.\n"Auto" picks the best option for your system.\nSwitching applies immediately — no restart needed.\n\nCurrent: ${GraphicsAPI.getActiveAPIDescription()}',
			'graphicsAPI',
			STRING,
			GraphicsAPI.getAvailableAPIs());
		option.onChange = onChangeGraphicsAPI;
		addOption(option);
		#end

		super();
		insert(1, boyfriend);
	}

	function onChangeAntiAliasing()
	{
		for (sprite in members)
		{
			var sprite:FlxSprite = cast sprite;
			if(sprite != null && (sprite is FlxSprite) && !(sprite is FlxText)) {
				sprite.antialiasing = ClientPrefs.data.antialiasing;
			}
		}
	}

	function onChangeVSync()
	{
		GraphicsAPI.applyVSync(ClientPrefs.data.vsync);
	}

	function onChangeGraphicsAPI()
	{
		var selected = ClientPrefs.data.graphicsAPI;

		if (selected != 'Auto')
		{
			var newAPI:GraphicsAPIType = cast selected;
			trace('Switching graphics API to: $selected...');
			var ok = GraphicsAPI.switchAPI(newAPI);
			if (ok)
				trace('Graphics API switched to: $selected');
			else
				trace('WARNING: could not switch to $selected');
		}
		else
		{
			var best = GraphicsAPI.detectBestAPI();
			trace('Auto mode — switching to best API: $best');
			GraphicsAPI.switchAPI(best);
		}
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		boyfriend.visible = (antialiasingOption == curSelected);
	}
}
