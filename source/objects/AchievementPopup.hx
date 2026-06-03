package objects;

#if ACHIEVEMENTS_ALLOWED
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import openfl.events.Event;

/**
 * AchievementPopup — bgfx-compatible version.
 *
 * Previously extended openfl.display.Sprite and used raw Graphics API
 * (beginFill/drawRect/beginBitmapFill). Now extends FlxSpriteGroup
 * and renders entirely through flixel's draw stack → bgfx.
 *
 * Uses a dedicated PsychCamera to stay on top across state switches.
 */
class AchievementPopup extends FlxSpriteGroup
{
	public var onFinish:Void->Void = null;

	var bg:FlxSprite;
	var icon:FlxSprite;
	var nameText:FlxText;
	var descText:FlxText;

	var lerpTime:Float = 0;
	var countedTime:Float = 0;
	var timePassed:Float = -1;
	public var intendedY:Float = 0;

	var lastScale:Float = 1;
	var popupCam:FlxCamera;

	public function new(achieve:String, onFinish:Void->Void)
	{
		super();

		this.onFinish = onFinish;

		// -- Background (rounded rectangle approximation as filled rect) --
		bg = new FlxSprite().makeGraphic(420, 130, FlxColor.BLACK);
		bg.alpha = 0.85;
		add(bg);

		// -- Achievement icon --
		var graphic = null;
		var hasAntialias:Bool = ClientPrefs.data.antialiasing;
		var image:String = 'achievements/$achieve';

		var achievement:Achievement = null;
		if (Achievements.exists(achieve)) achievement = Achievements.get(achieve);

		#if MODS_ALLOWED
		var lastMod = Mods.currentModDirectory;
		if (achievement != null) Mods.currentModDirectory = achievement.mod != null ? achievement.mod : '';
		#end

		if (Paths.fileExists('images/$image-pixel.png', IMAGE))
		{
			graphic = Paths.image('$image-pixel', false);
			hasAntialias = false;
		}
		else graphic = Paths.image(image, false);

		#if MODS_ALLOWED
		Mods.currentModDirectory = lastMod;
		#end

		if (graphic == null) graphic = Paths.image('unknownMod', false);

		icon = new FlxSprite(15, 15);
		icon.loadGraphic(graphic);
		icon.setGraphicSize(100, 100);
		icon.updateHitbox();
		icon.antialiasing = hasAntialias;
		add(icon);

		// -- Name / Description text --
		var name:String = 'Unknown';
		var desc:String = 'Description not found';
		if (achievement != null)
		{
			if (achievement.name != null) name = Language.getPhrase('achievement_$achieve', achievement.name);
			if (achievement.description != null) desc = Language.getPhrase('description_$achieve', achievement.description);
		}

		var textX = 130;
		nameText = new FlxText(textX, 35, 270, name, 16);
		nameText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		add(nameText);

		descText = new FlxText(textX, 65, 270, desc, 14);
		descText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT);
		add(descText);

		// -- Dedicated camera to render on top of everything --
		popupCam = new PsychCamera(0, 0, FlxG.width, FlxG.height);
		popupCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(popupCam, false);
		this.cameras = [popupCam];

		// -- Positioning --
		lastScale = (FlxG.stage.stageHeight / FlxG.height);
		this.x = 20 * lastScale;
		this.y = -130 * lastScale;
		this.scale.set(lastScale, lastScale);
		intendedY = 20;

		// -- Window resize handling --
		FlxG.stage.addEventListener(Event.RESIZE, onResize);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (timePassed < 0)
		{
			timePassed = openfl.Lib.getTimer();
			return;
		}

		var time = openfl.Lib.getTimer();
		var realElapsed:Float = (time - timePassed) / 1000;
		timePassed = time;

		if (realElapsed >= 0.5) return; // likely passed through a loading screen

		countedTime += realElapsed;
		if (countedTime < 3)
		{
			lerpTime = Math.min(1, lerpTime + realElapsed);
			y = ((FlxEase.elasticOut(lerpTime) * (intendedY + 130)) - 130) * lastScale;
		}
		else
		{
			y -= FlxG.height * 2 * realElapsed * lastScale;
			if (y <= -130 * lastScale)
				destroyPopup();
		}
	}

	function onResize(e:Event):Void
	{
		var mult = (FlxG.stage.stageHeight / FlxG.height);
		scale.set(mult, mult);

		x = (mult / lastScale) * x;
		y = (mult / lastScale) * y;
		lastScale = mult;
	}

	public function destroyPopup():Void
	{
		// Remove from camera list
		if (popupCam != null)
		{
			FlxG.cameras.remove(popupCam);
			popupCam = null;
		}

		FlxG.stage.removeEventListener(Event.RESIZE, onResize);

		Achievements._popups.remove(this);
		if (onFinish != null) onFinish();
		destroy();
	}
}
#end
