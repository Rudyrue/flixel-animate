package animate;

import animate.FlxAnimateController.FlxAnimateAnimation;
import animate.FormatJson;
import animate._internal.*;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.animation.FlxAnimationController;
import flixel.graphics.frames.FlxFramesCollection;
import haxe.Json;

class FlxAnimate extends FlxSprite
{
	public var library:FlxAnimateFrames;
	public var anim:FlxAnimateController;

	public var isAnimate(default, null):Bool = false;
	public var timeline:Timeline;

	override function initVars()
	{
		super.initVars();
		anim = new FlxAnimateController(this);
		animation = anim;
	}

	override function set_frames(frames:FlxFramesCollection):FlxFramesCollection
	{
		isAnimate = (frames is FlxAnimateFrames);

		if (isAnimate)
		{
			library = cast frames;
			timeline = library.timeline;
		}
		else
		{
			library = null;
			timeline = null;
		}

		return super.set_frames(frames);
	}

	override function draw()
	{
		if (!isAnimate)
		{
			super.draw();
			return;
		}

		for (camera in getCamerasLegacy())
		{
			if (!camera.visible || !camera.exists)
				continue;

			drawAnimate(camera);
		}
	}

	public var renderStage:Bool = false;

	function drawAnimate(camera:FlxCamera)
	{
		if (alpha <= 0 || scale.x == 0 || scale.y == 0)
			return;

		_matrix.setTo(flipX ? -1 : 1, 0, 0, flipY ? -1 : 1, 0, 0);

		if (renderStage)
			_matrix.concat(library.matrix);

		_matrix.translate(-origin.x, -origin.y);
		_matrix.scale(scale.x, scale.y);

		if (angle != 0)
		{
			updateTrig();
			_matrix.rotateWithTrig(_cosAngle, _sinAngle);
		}

		getScreenPosition(_point, camera);
		_point.add(-offset.x, -offset.y);
		_point.add(origin.x, origin.y);
		_matrix.translate(_point.x, _point.y);

		timeline.draw(camera, _matrix, colorTransform, blend, antialiasing, shader);
	}

	override function get_numFrames():Int
	{
		if (isAnimate)
			return animation.curAnim != null ? timeline.frameCount : 0;

		return super.get_numFrames();
	}

	override function destroy():Void
	{
		super.destroy();
		anim = null;
		library = null;
		timeline = null;
	}
}
