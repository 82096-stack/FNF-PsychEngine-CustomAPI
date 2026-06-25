package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * FSRSettingsSubState — Modal overlay for selecting FSR version and sharpness.
 *
 * Two-axis selector:
 *   UP/DOWN   — FSR version: FSR 1 (Spatial), FSR 2 (Temporal), FSR 3.1 (Temporal+)
 *   LEFT/RIGHT — Sharpness: None, Low, Medium, High, Ultra
 *
 * ACCEPT to confirm, BACK to cancel.
 */
class FSRSettingsSubState extends MusicBeatSubstate
{
	public var onConfirm:String->Float->Void = null;
	public var onCancel:Void->Void = null;

	// Version
	var versions:Array<String> = GraphicsSettingsSubState.getAvailableFSRVersions();
	var versionLabels:Array<String> = ['FSR 1 — Spatial (Fast)', 'FSR 2 — Temporal (Quality)', 'FSR 3.1 — Temporal+ (Best)'];
	var versionDescs:Array<String> = [
		'Spatial upscaling with edge-adaptive sharpening.\nWorks on ALL GPUs and graphics APIs.',
		'Temporal upscaling with anti-aliasing. Cross-API (D3D11/D3D12/Vulkan/Metal/OpenGL). Requires depth + motion vectors.',
		'Enhanced temporal upscaling with shading change detection. Cross-API (D3D11/D3D12/Vulkan/Metal/OpenGL). Best quality.'
	];
	var versionIndex:Int = 0;

	// Sharpness
	var levels:Array<Float> = [0.0, 0.25, 0.5, 0.75, 1.0];
	var labels:Array<String> = ['None', 'Low', 'Medium', 'High', 'Ultra'];
	var sharpIndex:Int = 2; // default Medium = 0.5

	// Sharpness descriptions
	var sharpDescs:Array<String> = [
		'None — No RCAS sharpening. EASU upscale only.',
		'Low (0.25) — Subtle sharpening. Minimal artifacts.',
		'Medium (0.5) — DEFAULT. Good balance.',
		'High (0.75) — Strong sharpening. May show haloing.',
		'Ultra (1.0) — Maximum sharpening. Visible artifacts possible.'
	];

	// UI
	var titleText:FlxText;
	var versionText:FlxText;
	var versionUpArrow:FlxText;
	var versionDownArrow:FlxText;
	var sharpnessText:FlxText;
	var leftArrow:FlxText;
	var rightArrow:FlxText;
	var descText:FlxText;
	var nextAccept:Int = 10;

	public function new(startVersion:String = 'FSR 1', startSharpness:Float = 0.5)
	{
		super();

		// Find closest version match
		versionIndex = 0;
		for (i in 0...versions.length)
			if (versions[i] == startVersion) { versionIndex = i; break; }

		// Find closest sharpness match
		sharpIndex = 2;
		for (i in 0...levels.length)
			if (Math.abs(levels[i] - startSharpness) < 0.01) { sharpIndex = i; break; }

		// Dark overlay
		var overlay = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		overlay.alpha = 0.85;
		overlay.scrollFactor.set(0, 0);
		add(overlay);

		// Title
		titleText = new FlxText(0, 80, FlxG.width, 'FSR Settings');
		titleText.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.scrollFactor.set(0, 0);
		add(titleText);

		// ── Version section (y=160) ──────────────────────────────────
		var versionLabel = new FlxText(0, 150, FlxG.width, 'Version (UP/DOWN)');
		versionLabel.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionLabel.scrollFactor.set(0, 0);
		add(versionLabel);

		versionUpArrow = new FlxText(FlxG.width / 2 - 32, 185, 64, '^');
		versionUpArrow.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionUpArrow.scrollFactor.set(0, 0);
		add(versionUpArrow);

		versionText = new FlxText(0, 210, FlxG.width, versionLabels[versionIndex]);
		versionText.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionText.scrollFactor.set(0, 0);
		add(versionText);

		versionDownArrow = new FlxText(FlxG.width / 2 - 32, 242, 64, 'v');
		versionDownArrow.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionDownArrow.scrollFactor.set(0, 0);
		add(versionDownArrow);

		// ── Sharpness section (y=310) ────────────────────────────────
		var sharpLabel = new FlxText(0, 290, FlxG.width, 'Sharpness (LEFT/RIGHT)');
		sharpLabel.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		sharpLabel.scrollFactor.set(0, 0);
		add(sharpLabel);

		leftArrow = new FlxText(0, 335, 100, '<');
		leftArrow.setFormat(Paths.font('vcr.ttf'), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		leftArrow.scrollFactor.set(0, 0);
		add(leftArrow);

		rightArrow = new FlxText(FlxG.width - 100, 335, 100, '>');
		rightArrow.setFormat(Paths.font('vcr.ttf'), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		rightArrow.scrollFactor.set(0, 0);
		add(rightArrow);

		sharpnessText = new FlxText(0, 340, FlxG.width, labels[sharpIndex] + ' (' + levels[sharpIndex] + ')');
		sharpnessText.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		sharpnessText.scrollFactor.set(0, 0);
		add(sharpnessText);

		// ── Description (y=420) ──────────────────────────────────────
		descText = new FlxText(0, 420, FlxG.width, getCurrentDescription());
		descText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set(0, 0);
		add(descText);

		// ── Instructions ─────────────────────────────────────────────
		var instruction = new FlxText(0, FlxG.height - 100, FlxG.width, 'ENTER to confirm   |   BACK to cancel');
		instruction.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		instruction.scrollFactor.set(0, 0);
		add(instruction);
	}

	function getCurrentDescription():String
	{
		return versionDescs[versionIndex] + '\n\n' + sharpDescs[sharpIndex];
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (nextAccept > 0) { nextAccept--; return; }

		// Version: UP/DOWN
		if (controls.UI_UP_P)
		{
			versionIndex = (versionIndex - 1 + versions.length) % versions.length;
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		if (controls.UI_DOWN_P)
		{
			versionIndex = (versionIndex + 1) % versions.length;
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		// Sharpness: LEFT/RIGHT
		if (controls.UI_LEFT_P)
		{
			sharpIndex = (sharpIndex - 1 + levels.length) % levels.length;
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		if (controls.UI_RIGHT_P)
		{
			sharpIndex = (sharpIndex + 1) % levels.length;
			updateDisplay();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		if (controls.ACCEPT)
		{
			if (onConfirm != null) onConfirm(versions[versionIndex], levels[sharpIndex]);
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
		versionText.text = versionLabels[versionIndex];
		versionText.screenCenter(X);
		sharpnessText.text = labels[sharpIndex] + ' (' + levels[sharpIndex] + ')';
		sharpnessText.screenCenter(X);
		descText.text = getCurrentDescription();
		descText.screenCenter(X);
	}
}
