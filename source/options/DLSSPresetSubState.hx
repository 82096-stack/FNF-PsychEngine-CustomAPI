package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * DLSSPresetSubState — Modal overlay for selecting DLSS render preset.
 *
 * Presets A-M (matching NVIDIA NGX SDK DLSS_BRIDGE_PRESET_* values):
 *   A-D: Legacy (removed from SDK but passable)
 *   E-F: Deprecated (still available)
 *   J-M: Current (J=similar to K, K=best quality, L=UltraPerf, M=Perf)
 *
 * LEFT/RIGHT to switch, ACCEPT to confirm, BACK to cancel.
 */
class DLSSPresetSubState extends MusicBeatSubstate
{
	public var onConfirm:String->Void = null;
	public var onCancel:Void->Void = null;

	var presets:Array<String> = ['A', 'B', 'C', 'D', 'E', 'F', 'J', 'K', 'L', 'M'];
	var curIndex:Int = 7; // default K

	var titleText:FlxText;
	var presetText:FlxText;
	var descText:FlxText;
	var leftArrow:FlxText;
	var rightArrow:FlxText;
	var nextAccept:Int = 10;

	public function new(startPreset:String = 'K')
	{
		super();

		curIndex = presets.indexOf(startPreset);
		if (curIndex < 0) curIndex = 7; // default K

		// Overlay
		var overlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		overlay.alpha = 0.85;
		overlay.scrollFactor.set(0, 0);
		add(overlay);

		// Title
		titleText = new FlxText(0, 120, FlxG.width, 'DLSS Preset');
		titleText.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.scrollFactor.set(0, 0);
		add(titleText);

		// Arrows
		leftArrow = new FlxText(0, 0, 100, '<');
		leftArrow.setFormat(Paths.font('vcr.ttf'), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		leftArrow.scrollFactor.set(0, 0);
		leftArrow.screenCenter(Y);
		add(leftArrow);

		rightArrow = new FlxText(FlxG.width - 100, 0, 100, '>');
		rightArrow.setFormat(Paths.font('vcr.ttf'), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		rightArrow.scrollFactor.set(0, 0);
		rightArrow.screenCenter(Y);
		add(rightArrow);

		// Current preset
		presetText = new FlxText(0, 0, FlxG.width, presets[curIndex]);
		presetText.setFormat(Paths.font('vcr.ttf'), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		presetText.scrollFactor.set(0, 0);
		presetText.screenCenter();
		add(presetText);

		// Description
		descText = new FlxText(0, presetText.y + 60, FlxG.width, getDescription(curIndex));
		descText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set(0, 0);
		add(descText);

		var instruction = new FlxText(0, FlxG.height - 120, FlxG.width, 'ENTER to confirm   |   BACK to cancel');
		instruction.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		instruction.scrollFactor.set(0, 0);
		add(instruction);
	}

	function getDescription(index:Int):String
	{
		return switch(index)
		{
			case 0: 'Preset A (legacy, removed from SDK)';
			case 1: 'Preset B (legacy, removed from SDK)';
			case 2: 'Preset C (legacy, removed from SDK)';
			case 3: 'Preset D (legacy, removed from SDK)';
			case 4: 'Preset E (deprecated, still available)';
			case 5: 'Preset F (deprecated, still available)';
			case 6: 'Preset J — less ghosting, more flickering';
			case 7: 'Preset K — NEWEST DEFAULT. Transformer-based, best quality';
			case 8: 'Preset L — Default for Ultra Performance mode';
			case 9: 'Preset M — Default for Performance mode';
			default: '';
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (nextAccept > 0) { nextAccept--; return; }

		if (controls.UI_LEFT_P)
		{
			curIndex = (curIndex - 1 + presets.length) % presets.length;
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		if (controls.UI_RIGHT_P)
		{
			curIndex = (curIndex + 1) % presets.length;
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		if (controls.ACCEPT)
		{
			if (onConfirm != null) onConfirm(presets[curIndex]);
			close();
		}
		if (controls.BACK)
		{
			if (onCancel != null) onCancel();
			close();
		}
	}

	function updateDisplay():Void
	{
		presetText.text = presets[curIndex];
		presetText.screenCenter(X);
		descText.text = getDescription(curIndex);
		descText.screenCenter(X);
	}
}
