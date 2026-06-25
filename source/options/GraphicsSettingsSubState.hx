package options;

import objects.Character;
import backend.GraphicsAPI;
import backend.GraphicsAPIType;
import backend.GPUDetect;
import backend.ClientPrefs;
import backend.BgfxWindowManager;
import backend.RenderDevice;
import backend.upscale.DirectEnlargeUpscaler;
import backend.upscale.NISUpscaler;
import backend.upscale.FSRUpscaler;
import backend.upscale.FSR2Upscaler;
import backend.upscale.FSR3Upscaler;
import backend.upscale.DLSSUpscaler;
import backend.upscale.XeSSUpscaler;
#if mac
import backend.upscale.MetalFXUpscaler;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.app.Application;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var boyfriend:Character = null;
	var graphicsAPIOptionIndex:Int = -1;
	var originalAPI:String;
	var resolutionOptionIndex:Int = -1;
	var upscalerOptionIndex:Int = -1;

	var testingOverlay:FlxSprite;
	var testingText:FlxText;
	var completeText:FlxText;
	var isTesting:Bool = false;
	var completeTimer:Float = 0;
	var completePhase:Int = 0;

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

		#if !html5
		var resolutions:Array<String> = ['240p','360p','480p','720p','1080p','1440p','2160p','2880p','3240p','4320p','8640p'];
		var resOption:Option = new Option('Resolution',
			'Internal render resolution.\nPress ENTER to apply (auto-upscales from 720p when > 720p).',
			'resolution', STRING, resolutions);
		resOption.onChange = onChangeResolution;
		addOption(resOption);
		resolutionOptionIndex = optionsArray.length - 1;

		var upscalers:Array<String> = getAvailableUpscalers();
		var upscaleOption:Option = new Option('Upscaler',
			'Upscaling method when resolution > 720p.',
			'upscaler', STRING, upscalers);
		upscaleOption.onChange = onChangeUpscaler;
		addOption(upscaleOption);
		upscalerOptionIndex = optionsArray.length - 1;

		onChangeResolution();
		#end

		addOption(new Option('Low Quality',
			'If checked, disables some background details,\ndecreases loading times and improves performance.',
			'lowQuality', BOOL));
		addOption(new Option('Anti-Aliasing',
			'If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals.',
			'antialiasing', BOOL));
		antialiasingOption = optionsArray.length - 1;
		(cast members[antialiasingOption+1]).onChange = onChangeAntiAliasing;

		addOption(new Option('Shaders', "If unchecked, disables shaders.\nIt's used for some visual effects, and also CPU intensive for weaker PCs.",
			'shaders', BOOL));
		addOption(new Option('GPU Caching',
			"If checked, allows the GPU to be used for caching textures, decreasing RAM usage.\nDon't turn this on if you have a shitty Graphics Card.",
			'cacheOnGPU', BOOL));

		#if !html5
		var opt:Option = new Option('V-Sync',
			'If checked, caps the framerate to your display refresh rate.',
			'vsync', BOOL);
		opt.onChange = onChangeVSync;
		addOption(opt);

		var opt:Option = new Option('Graphics API', '',
			'graphicsAPI', STRING, GraphicsAPI.getAvailableAPIs());
		opt.onChange = refreshAPIDescription;
		addOption(opt);
		graphicsAPIOptionIndex = optionsArray.length - 1;

		var opt:Option = new Option('DLSS Preset',
			'DLSS render preset A-M. Press ENTER to select.\nCurrent: ' + ClientPrefs.data.dlssPreset,
			'dlssPreset', STRING, []);
		opt.onAccept = openDLSSPresetSelector;
		addOption(opt);

		var opt:Option = new Option('FSR Settings',
			'FSR version & sharpness. Press ENTER to select.\nCurrent: ' + ClientPrefs.data.fsrVersion + ' | Sharpness: ' + ClientPrefs.data.fsrSharpness,
			'fsrSharpness', STRING, []);
		opt.onAccept = openFSRSettingsSelector;
		addOption(opt);

		#if mac
		var opt:Option = new Option('MetalFX Mode',
			'MetalFX upscaling mode. Press ENTER to select.\nCurrent: ' + ClientPrefs.data.metalfxMode,
			'metalfxMode', STRING, []);
		opt.onAccept = openMetalFXModeSelector;
		addOption(opt);
		#end

		var opt:Option = new Option('DirectEnlarge Filter',
			'Filter mode for DirectEnlarge upscaler. Press ENTER to select.\nCurrent: ' + ClientPrefs.data.directEnlargeFilter,
			'directEnlargeFilter', STRING, []);
		opt.onAccept = openDirectEnlargeFilterSelector;
		addOption(opt);
		#end

		super();
		insert(1, boyfriend);

		testingOverlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(64,64,64));
		testingOverlay.alpha = 0.7;
		testingOverlay.scrollFactor.set(0,0);
		testingOverlay.visible = false;
		add(testingOverlay);

		testingText = new FlxText(0, 0, FlxG.width, 'Testing In Progress');
		testingText.setFormat(Paths.font('vcr.ttf'), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		testingText.screenCenter();
		testingText.scrollFactor.set(0,0);
		testingText.visible = false;
		add(testingText);

		completeText = new FlxText(0, 30, FlxG.width, 'Testing Complete!');
		completeText.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		completeText.scrollFactor.set(0,0);
		completeText.alpha = 0;
		completeText.visible = false;
		add(completeText);

		originalAPI = ClientPrefs.data.graphicsAPI;
		refreshAPIDescription();
	}

	function onChangeResolution()
	{
		var wh = Main.getResolutionDimensions(ClientPrefs.data.resolution);
		if (wh == null) return;
		if (resolutionOptionIndex >= 0)
		{
			var opt = optionsArray[resolutionOptionIndex];
			var name = ClientPrefs.data.upscaler;
			var hint = (wh.height > 720)
				? 'Will upscale from 720p using ' + name
				: 'Native rendering (no upscaling needed)';
			opt.description = 'Internal render resolution.\nSelected: ' + wh.width + 'x' + wh.height + '\n' + hint + '\nPress ENTER to apply.';
		}
	}

	function autoApplyUpscaleForResolution(resolutionKey:String):Void
	{
		var wh = Main.getResolutionDimensions(resolutionKey);
		if (wh == null) return;
		if (wh.height <= 720)
		{
			RenderDevice.destroyRenderTargets();
			RenderDevice.setUpscaler(null, 'None');
			ClientPrefs.saveSettings();
			return;
		}
		RenderDevice.initRenderTargets(1280, 720, wh.width, wh.height);
		var name = ClientPrefs.data.upscaler;
		var upscaler = createUpscalerWithDefaults(name);
		RenderDevice.setUpscaler(upscaler, name);
		ClientPrefs.saveSettings();
	}

	function createUpscalerWithDefaults(name:String):backend.upscale.IUpscaler
	{
		return switch(name)
		{
			case 'DLSS':
				var dlss = new DLSSUpscaler();
				dlss.preset = ClientPrefs.data.dlssPreset;
				dlss;
			case 'XeSS':
				new XeSSUpscaler();
			case 'FSR':
				var fsr = switch(ClientPrefs.data.fsrVersion) {
					case 'FSR 2': new FSR2Upscaler();
					case 'FSR 3.1': new FSR3Upscaler();
					default:
						var f = new FSRUpscaler();
						f.sharpness = ClientPrefs.data.fsrSharpness;
						f;
				}
				fsr;
			case 'NIS':
				var nis = new NISUpscaler();
				nis.sharpness = 0.5;
				nis;
			#if mac
			case 'MetalFX':
				var mfx = new MetalFXUpscaler();
				mfx.mode = ClientPrefs.data.metalfxMode;
				mfx;
			#end
			default:
				var de = new DirectEnlargeUpscaler();
				de.filterMode = ClientPrefs.data.directEnlargeFilter;
				de;
		}
	}

	static function getAvailableUpscalers():Array<String>
	{
		var base = ['Directly Enlarge', 'FSR', 'NIS'];
		var api = RenderDevice.activeAPI;
		if (api == 'DirectX 12' || api == 'DirectX 11' || api == 'Vulkan')
			base.insert(1, 'DLSS');
		if (api == 'DirectX 12' || api == 'Vulkan')
			base.insert(1, 'XeSS');
		#if mac
		if (api == 'Metal') base.push('MetalFX');
		#end
		return base;
	}

	public static function getAvailableFSRVersions():Array<String>
	{
		if (RenderDevice.activeAPI == 'DirectX 12')
			return ['FSR 1', 'FSR 2', 'FSR 3.1'];
		return ['FSR 1'];
	}

	function openDLSSPresetSelector():Bool
	{
		persistentUpdate = false;
		openSubState(new DLSSPresetSubState(ClientPrefs.data.dlssPreset));
		var sub:DLSSPresetSubState = cast subState;
		sub.onConfirm = function(p:String) {
			ClientPrefs.data.dlssPreset = p;
			ClientPrefs.saveSettings();
			autoApplyUpscaleForResolution(ClientPrefs.data.resolution);
			FlxG.sound.play(Paths.sound('confirmMenu'));
			persistentUpdate = true;
		};
		sub.onCancel = function() {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			persistentUpdate = true;
		};
		return true;
	}

	function openFSRSettingsSelector():Bool
	{
		persistentUpdate = false;
		openSubState(new FSRSettingsSubState(ClientPrefs.data.fsrVersion, ClientPrefs.data.fsrSharpness));
		var sub:FSRSettingsSubState = cast subState;
		sub.onConfirm = function(version:String, sharpness:Float) {
			ClientPrefs.data.fsrVersion = version;
			ClientPrefs.data.fsrSharpness = sharpness;
			ClientPrefs.saveSettings();
			autoApplyUpscaleForResolution(ClientPrefs.data.resolution);
			FlxG.sound.play(Paths.sound('confirmMenu'));
			persistentUpdate = true;
		};
		sub.onCancel = function() {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			persistentUpdate = true;
		};
		return true;
	}

	function openDirectEnlargeFilterSelector():Bool
	{
		persistentUpdate = false;
		openSubState(new DirectEnlargeFilterSubState(ClientPrefs.data.directEnlargeFilter));
		var sub:DirectEnlargeFilterSubState = cast subState;
		sub.onConfirm = function(f:String) {
			ClientPrefs.data.directEnlargeFilter = f;
			ClientPrefs.saveSettings();
			autoApplyUpscaleForResolution(ClientPrefs.data.resolution);
			FlxG.sound.play(Paths.sound('confirmMenu'));
			persistentUpdate = true;
		};
		sub.onCancel = function() {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			persistentUpdate = true;
		};
		return true;
	}

	function openMetalFXModeSelector():Bool
	{
		persistentUpdate = false;
		openSubState(new MetalFXModeSubState(ClientPrefs.data.metalfxMode));
		var sub:MetalFXModeSubState = cast subState;
		sub.onConfirm = function(m:String) {
			ClientPrefs.data.metalfxMode = m;
			ClientPrefs.saveSettings();
			autoApplyUpscaleForResolution(ClientPrefs.data.resolution);
			FlxG.sound.play(Paths.sound('confirmMenu'));
			persistentUpdate = true;
		};
		sub.onCancel = function() {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			persistentUpdate = true;
		};
		return true;
	}

	function onChangeAntiAliasing()
	{
		for (sprite in members)
		{
			var sprite:FlxSprite = cast sprite;
			if (sprite != null && (sprite is FlxSprite) && !(sprite is FlxText))
				sprite.antialiasing = ClientPrefs.data.antialiasing;
		}
	}

	function onChangeVSync()
	{
		GraphicsAPI.applyVSync(ClientPrefs.data.vsync);
	}

	function onChangeUpscaler()
	{
		autoApplyUpscaleForResolution(ClientPrefs.data.resolution);
		onChangeResolution();
	}

	function refreshAPIDescription()
	{
		var cur = GraphicsAPI.getActiveAPIDescription();
		var preview = ClientPrefs.data.graphicsAPI;
		if (preview == 'Auto') preview = GraphicsAPI.detectBestAPI();
		var opt = optionsArray[graphicsAPIOptionIndex];
		opt.description = 'Select API then press ENTER to confirm.\nCurrent: ' + cur + '\nPreview: ' + preview;
		@:privateAccess descText.text = opt.description;
		@:privateAccess descText.screenCenter(Y);
		@:privateAccess descText.y += 270;
	}

	function runBenchmark()
	{
		var best = GraphicsAPI.benchmarkBestAPI();
		GraphicsAPI.switchAPI(best);
		ClientPrefs.saveSettings();
		refreshAPIDescription();
		isTesting = false;
		testingOverlay.visible = false;
		testingText.visible = false;
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

		if (completePhase == 2)
		{
			completeTimer += elapsed;
			if (completeTimer >= 1.0) { completePhase = 3; completeTimer = 0; }
		}
		else if (completePhase == 3)
		{
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

		#if !html5
		if (resolutionOptionIndex >= 0 && curSelected == resolutionOptionIndex
			&& FlxG.keys.justPressed.ENTER && !isTesting && completePhase == 0)
		{
			autoApplyUpscaleForResolution(ClientPrefs.data.resolution);
			FlxG.sound.play(Paths.sound('confirmMenu'));
			onChangeResolution();
		}
		#end

		if (graphicsAPIOptionIndex >= 0 && curSelected == graphicsAPIOptionIndex
			&& FlxG.keys.justPressed.ENTER && !isTesting && completePhase == 0)
		{
			var sel = ClientPrefs.data.graphicsAPI;
			if (sel != 'Auto')
			{
				GraphicsAPI.switchAPI(cast sel);
				originalAPI = sel;
				ClientPrefs.saveSettings();
				refreshAPIDescription();
				FlxG.sound.play(Paths.sound('confirmMenu'));
			}
			else
			{
				isTesting = true;
				completePhase = 1;
				testingOverlay.visible = true;
				testingText.visible = true;
				originalAPI = sel;
				haxe.Timer.delay(runBenchmark, 100);
			}
		}
	}

	override function close()
	{
		if (isTesting) return;
		if (ClientPrefs.data.graphicsAPI != originalAPI)
			ClientPrefs.data.graphicsAPI = originalAPI;
		super.close();
	}

	override function changeSelection(change:Int = 0)
	{
		if (isTesting) return;
		super.changeSelection(change);
		boyfriend.visible = (antialiasingOption == curSelected);
	}
}
