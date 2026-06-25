package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * DirectEnlargeFilterSubState — Modal overlay for selecting DirectEnlarge filter mode.
 *
 * Three modes:
 *   Bilinear — Smooth interpolation (default). Good for general use.
 *   Nearest  — Pixel-art style. No blending between pixels.
 *   Bicubic  — Sharp scaling with anisotropic edge preservation.
 *
 * LEFT/RIGHT to switch, ACCEPT to confirm, BACK to cancel.
 */
class DirectEnlargeFilterSubState extends MusicBeatSubstate
{
	public var onConfirm:String->Void = null;
	public var onCancel:Void->Void = null;

	var filters:Array<String> = ['Bilinear', 'Nearest', 'Bicubic'];
	var curIndex:Int = 0;

	var titleText:FlxText;
	var filterText:FlxText;
	var descText:FlxText;
	var leftArrow:FlxText;
	var rightArrow:FlxText;

	var nextAccept:Int = 10;

	public function new(startFilter:String = 'Bilinear')
	{
		super();

		curIndex = (startFilter == 'Nearest') ? 1 : ((startFilter == 'Bicubic') ? 2 : 0);

		// Full-screen dark overlay
		var overlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		overlay.alpha = 0.85;
		overlay.scrollFactor.set(0, 0);
		add(overlay);

		// Title
		titleText = new FlxText(0, 120, FlxG.width, 'DirectEnlarge Filter');
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

		// Current filter (large, centered)
		filterText = new FlxText(0, 0, FlxG.width, filters[curIndex]);
		filterText.setFormat(Paths.font('vcr.ttf'), 48, FlxColor.WHITE, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		filterText.scrollFactor.set(0, 0);
		filterText.screenCenter();
		add(filterText);

		// Description
		descText = new FlxText(0, filterText.y + 60, FlxG.width, getDescription(curIndex));
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
			case 0: 'Bilinear — Smooth interpolation.\nDefault mode. Good for general use.\nWorks on all GPUs.';
			case 1: 'Nearest — Pixel-art style.\nNo blending between pixels.\nBest for retro/pixel games.';
			case 2: 'Bicubic — Sharp scaling with anisotropic filtering.\nPreserves edge details.\nHighest quality hardware filter.';
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
			curIndex--;
			if (curIndex < 0) curIndex = filters.length - 1;
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		if (controls.UI_RIGHT_P)
		{
			curIndex++;
			if (curIndex >= filters.length) curIndex = 0;
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		if (controls.ACCEPT)
		{
			if (onConfirm != null)
				onConfirm(filters[curIndex]);
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
		filterText.text = filters[curIndex];
		filterText.screenCenter(X);
		descText.text = getDescription(curIndex);
		descText.screenCenter(X);
	}
}
