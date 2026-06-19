package options;

import objects.Character;
import backend.GraphicsAPI;
import backend.GraphicsAPIType;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var boyfriend:Character = null;
	var graphicsAPIOptionIndex:Int = -1;
	var originalAPI:String;

	// ── Benchmark UI state ────────────────────────────────────────
	var testingOverlay:FlxSprite;
	var testingText:FlxText;
	var completeText:FlxText;
	var isTesting:Bool = false;          // true while benchmark running or completing
	var benchmarkPending:Bool = false;   // true during delay before benchmark starts
	var completeTimer:Float = 0;
	var completePhase:Int = 0;           // 0=idle, 1=testing, 2=hold 1s, 3=fade 0.5s
	var pendingAPI:String = null;        // API to switch to if not Auto, or null for Auto

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

		// ── Benchmark overlay (hidden initially) ───────────────────
		testingOverlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(64, 64, 64));
		testingOverlay.alpha = 0.7;
		testingOverlay.scrollFactor.set(0, 0);
		testingOverlay.visible = false;
		add(testingOverlay);

		testingText = new FlxText(0, 0, FlxG.width, 'Testing In Progress');
		testingText.setFormat(Paths.font('vcr.ttf'), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		testingText.screenCenter();
		testingText.scrollFactor.set(0, 0);
		testingText.visible = false;
		add(testingText);

		completeText = new FlxText(0, 30, FlxG.width, 'Testing Complete!');
		completeText.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		completeText.x = 0;
		completeText.y = 30;
		completeText.scrollFactor.set(0, 0);
		completeText.alpha = 0;
		completeText.visible = false;
		add(completeText);

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

	/**
	 * Called by haxe.Timer.delay after the overlay has been rendered for
	 * one frame, so the user sees "Testing In Progress" before we block.
	 */
	function runBenchmark()
	{
		var best = GraphicsAPI.benchmarkBestAPI();
		GraphicsAPI.switchAPI(best);

		ClientPrefs.saveSettings();
		refreshAPIDescription();

		// Hide overlay, show "Testing Complete!" — allow interaction now
		isTesting = false;
		testingOverlay.visible = false;
		testingText.visible = false;
		benchmarkPending = false;
		completePhase = 2;
		completeTimer = 0;
		completeText.visible = true;
		completeText.alpha = 1.0;
		completeText.screenCenter(X);

		FlxG.sound.play(Paths.sound('confirmMenu'));
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// ── "Testing Complete!" animation ──────────────────────────
		if (completePhase == 2)
		{
			// Hold "Testing Complete!" visible for 1 second
			completeTimer += elapsed;
			if (completeTimer >= 1.0)
			{
				completePhase = 3;
				completeTimer = 0;
			}
		}
		else if (completePhase == 3)
		{
			// Fade out over 0.5 seconds
			completeTimer += elapsed;
			completeText.alpha = 1.0 - (completeTimer / 0.5);
			if (completeTimer >= 0.5)
			{
				completeText.alpha = 0;
				completeText.visible = false;
				completePhase = 0;
				isTesting = false;
			}
		}

		// ── ENTER key on Graphics API option ───────────────────────
		if (graphicsAPIOptionIndex >= 0 && curSelected == graphicsAPIOptionIndex
			&& FlxG.keys.justPressed.ENTER && !isTesting && completePhase == 0)
		{
			var selected = ClientPrefs.data.graphicsAPI;
			if (selected != 'Auto')
			{
				GraphicsAPI.switchAPI(cast selected);
				originalAPI = selected;
				ClientPrefs.saveSettings();
				refreshAPIDescription();
				FlxG.sound.play(Paths.sound('confirmMenu'));
			}
			else
			{
				// Show overlay immediately
				isTesting = true;
				benchmarkPending = true;
				completePhase = 1;
				testingOverlay.visible = true;
				testingText.visible = true;
				originalAPI = selected;

				// Defer benchmark by one frame so the overlay actually renders
				// before the main thread blocks on benchmarkBestAPI()
				haxe.Timer.delay(runBenchmark, 100);
			}
		}
	}

	override function close()
	{
		// Block closing only while benchmark is actually running
		if (isTesting) return;
		if (ClientPrefs.data.graphicsAPI != originalAPI)
			ClientPrefs.data.graphicsAPI = originalAPI;
		super.close();
	}

	override function changeSelection(change:Int = 0)
	{
		// Block navigation only while benchmark is actually running
		if (isTesting) return;
		super.changeSelection(change);
		boyfriend.visible = (antialiasingOption == curSelected);
	}
}
