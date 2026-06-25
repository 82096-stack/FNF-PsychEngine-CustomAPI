package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * MetalFXModeSubState — Modal overlay for selecting MetalFX upscaling mode.
 *
 * Two modes:
 *   Spatial  — Single-frame upscale. No depth/motion needed. Best for 2D.
 *   Temporal — Multi-frame upscale with anti-aliasing.
 *              Uses flat depth + zero motion for 2D games.
 *
 * LEFT/RIGHT to switch, ACCEPT to confirm, BACK to cancel.
 */
class MetalFXModeSubState extends MusicBeatSubstate
{
	public var onConfirm:String->Void = null;
	public var onCancel:Void->Void = null;

	var modes:Array<String> = ['Spatial', 'Temporal'];
	var curMode:Int = 0;

	var titleText:FlxText;
	var modeText:FlxText;
	var descText:FlxText;
	var leftArrow:FlxText;
	var rightArrow:FlxText;

	var nextAccept:Int = 10;

	public function new(startMode:String = 'Spatial')
	{
		super();

		curMode = (startMode == 'Temporal') ? 1 : 0;

		// Full-screen dark overlay
		var overlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		overlay.alpha = 0.85;
		overlay.scrollFactor.set(0, 0);
		add(overlay);

		// Title
		titleText = new FlxText(0, 120, FlxG.width, 'MetalFX Mode');
		titleText.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.scrollFactor.set(0, 0);
		add(titleText);

		// Left arrow
		leftArrow = new FlxText(0, 0, 100, '<');
		leftArrow.setFormat(Paths.font('vcr.ttf'), 64, FlxColor.WHITE, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		leftArrow.scrollFactor.set(0, 0);
		leftArrow.screenCenter(Y);
		add(leftArrow);

		// Right arrow
		rightArrow = new FlxText(FlxG.width - 100, 0, 100, '>');
		rightArrow.setFormat(Paths.font('vcr.ttf'), 64, FlxColor.WHITE, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		rightArrow.scrollFactor.set(0, 0);
		rightArrow.screenCenter(Y);
		add(rightArrow);

		// Current mode (large, centered)
		modeText = new FlxText(0, 0, FlxG.width, modes[curMode]);
		modeText.setFormat(Paths.font('vcr.ttf'), 48, FlxColor.WHITE, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		modeText.scrollFactor.set(0, 0);
		modeText.screenCenter();
		add(modeText);

		// Description
		descText = new FlxText(0, modeText.y + 60, FlxG.width, getDescription(curMode));
		descText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set(0, 0);
		add(descText);

		// Instructions
		var instructionText = new FlxText(0, FlxG.height - 120, FlxG.width,
			'ENTER to confirm   |   BACK to cancel');
		instructionText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		instructionText.scrollFactor.set(0, 0);
		add(instructionText);
	}

	function getDescription(index:Int):String
	{
		return switch(index)
		{
			case 0: 'Single-frame spatial upscale.\nNo depth or motion vectors needed.\nFast, best for 2D games.';
			case 1: 'Multi-frame temporal upscale with anti-aliasing.\nUses flat depth + zero motion for 2D.\nHigher quality, slightly more GPU cost.';
			default: '';
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (nextAccept > 0)
		{
			nextAccept--;
			return;
		}

		if (controls.UI_LEFT_P)
		{
			curMode--;
			if (curMode < 0) curMode = modes.length - 1;
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		if (controls.UI_RIGHT_P)
		{
			curMode++;
			if (curMode >= modes.length) curMode = 0;
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		if (controls.ACCEPT)
		{
			if (onConfirm != null)
				onConfirm(modes[curMode]);
			close();
		}

		if (controls.BACK)
		{
			if (onCancel != null)
				onCancel();
			close();
		}
	}

	function updateDisplay():Void
	{
		modeText.text = modes[curMode];
		modeText.screenCenter(X);
		descText.text = getDescription(curMode);
		descText.screenCenter(X);
	}
}
