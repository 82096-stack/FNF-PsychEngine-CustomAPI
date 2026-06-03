package options;

import objects.Character;
import backend.GraphicsAPI;
import backend.GraphicsAPIType;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var boyfriend:Character = null;
	var graphicsAPIOptionIndex:Int = -1;
	var originalAPI:String;

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

		var option:Option = new Option('Graphics API',
			'',
			'graphicsAPI',
			STRING,
			GraphicsAPI.getAvailableAPIs());
		option.onChange = refreshAPIDescription;
		addOption(option);
		graphicsAPIOptionIndex = optionsArray.length - 1;
		#end

		super();
		insert(1, boyfriend);

		// Remember original value so we can restore on BACK
		originalAPI = ClientPrefs.data.graphicsAPI;
		refreshAPIDescription();
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

	function refreshAPIDescription()
	{
		var current = GraphicsAPI.getActiveAPIDescription();
		var preview = ClientPrefs.data.graphicsAPI;
		if (preview == 'Auto') preview = GraphicsAPI.detectBestAPI();
		var apiOption = optionsArray[graphicsAPIOptionIndex];
		apiOption.description = 'Select API then press ENTER to confirm.\nCurrent: $current\nPreview: $preview';

		@:privateAccess descText.text = apiOption.description;
		@:privateAccess descText.screenCenter(Y);
		@:privateAccess descText.y += 270;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (graphicsAPIOptionIndex >= 0 && curSelected == graphicsAPIOptionIndex
			&& FlxG.keys.justPressed.ENTER)
		{
			var selected = ClientPrefs.data.graphicsAPI;
			if (selected != 'Auto')
				GraphicsAPI.switchAPI(cast selected);
			else
				GraphicsAPI.switchAPI(GraphicsAPI.detectBestAPI());

			originalAPI = selected;
			ClientPrefs.saveSettings();
			refreshAPIDescription();
			FlxG.sound.play(Paths.sound('confirmMenu'));
		}
	}

	override function close()
	{
		// Restore original API if user didn't press ENTER
		if (ClientPrefs.data.graphicsAPI != originalAPI)
			ClientPrefs.data.graphicsAPI = originalAPI;

		super.close();
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		boyfriend.visible = (antialiasingOption == curSelected);
	}
}
