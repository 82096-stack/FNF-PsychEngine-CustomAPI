package states;

import backend.GraphicsAPI;
import backend.ClientPrefs;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.FlxSubState;

/**
 * First-run dialog shown before TitleState.
 *
 * Asks the user whether they want to benchmark all available graphics APIs
 * to find the best one for their computer, or skip and use OpenGL.
 *
 * Navigation: LEFT / RIGHT to choose. ACCEPT to confirm.
 * Result is saved to ClientPrefs and the dialog never appears again.
 */
class FirstRunAPIState extends FlxSubState
{
	var bg:FlxSprite;
	var overlay:FlxSprite;
	var titleText:FlxText;
	var questionText:FlxText;
	var yesText:FlxText;
	var noText:FlxText;
	var selectedYes:Bool = true;

	public function new()
	{
		super();
	}

	override function create()
	{
		super.create();

		// Dark background
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.scrollFactor.set(0, 0);
		bg.alpha = 0.85;
		add(bg);

		// Title
		titleText = new FlxText(0, 60, FlxG.width, 'Welcome!');
		titleText.setFormat(Paths.font('vcr.ttf'), 40, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.scrollFactor.set(0, 0);
		add(titleText);

		// Question
		questionText = new FlxText(20, 0, FlxG.width - 40,
			'Looks like it is your first time running\nthe Custom API Psych Engine!\n\nDo you want to do a test for the best\ngraphics API for your computer?');
		questionText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		questionText.screenCenter(Y);
		questionText.y -= 40;
		questionText.scrollFactor.set(0, 0);
		add(questionText);

		// Yes / No options
		yesText = new FlxText(0, 0, FlxG.width / 2 - 20, '> Yes <');
		yesText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.LIME, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		yesText.screenCenter(Y);
		yesText.y += 120;
		yesText.x = -30;
		yesText.scrollFactor.set(0, 0);
		add(yesText);

		noText = new FlxText(0, 0, FlxG.width / 2 - 20, 'No');
		noText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		noText.screenCenter(Y);
		noText.y += 120;
		noText.x = FlxG.width / 2 + 30;
		noText.scrollFactor.set(0, 0);
		add(noText);

		updateSelection();
	}

	function updateSelection()
	{
		if (selectedYes)
		{
			yesText.text = '> Yes <';
			yesText.color = FlxColor.LIME;
			noText.text = 'No';
			noText.color = FlxColor.WHITE;
		}
		else
		{
			yesText.text = 'Yes';
			yesText.color = FlxColor.WHITE;
			noText.text = '> No <';
			noText.color = FlxColor.RED;
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.RIGHT)
		{
			selectedYes = !selectedYes;
			updateSelection();
		}

		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
		{
			confirmSelection();
		}

		// Also support gamepad
		#if !FLX_NO_GAMEPAD
		var gamepad = FlxG.gamepads.lastActive;
		if (gamepad != null)
		{
			if (gamepad.justPressed.DPAD_LEFT || gamepad.justPressed.DPAD_RIGHT)
			{
				selectedYes = !selectedYes;
				updateSelection();
			}
			if (gamepad.justPressed.A || gamepad.justPressed.START)
			{
				confirmSelection();
			}
		}
		#end
	}

	function confirmSelection()
	{
		// Mark that first-run dialog has been shown
		ClientPrefs.data.firstRunAPI = false;
		FlxG.save.data.firstRunAPI = false;
		FlxG.save.flush();

		if (selectedYes)
		{
			// Show testing overlay then run benchmark
			close();

			// We need to defer the benchmark so the substate closes first,
			// otherwise the screen stays frozen on the dialog during the test.
			// After this substate closes, TitleState takes over. We can run
			// the benchmark asynchronously via haxe.Timer.
			// Actually, the benchmark blocks. So we close, let TitleState render,
			// then run via a timer.
			haxe.Timer.delay(function() {
				var best = GraphicsAPI.benchmarkBestAPI();
				ClientPrefs.data.graphicsAPI = cast best;
				FlxG.save.data.graphicsAPI = cast best;
				FlxG.save.flush();
				// Switch to the best API
				GraphicsAPI.switchAPI(best);
			}, 200);
		}
		else
		{
			// Skip benchmark, use OpenGL
			ClientPrefs.data.graphicsAPI = 'OpenGL';
			FlxG.save.data.graphicsAPI = 'OpenGL';
			FlxG.save.flush();
			GraphicsAPI.switchAPI(OpenGL);
			close();
		}
	}
}
