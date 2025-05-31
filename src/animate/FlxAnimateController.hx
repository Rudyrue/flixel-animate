package animate;

import animate._internal.*;
import flixel.FlxG;
import flixel.animation.FlxAnimation;
import flixel.animation.FlxAnimationController;

class FlxAnimateController extends FlxAnimationController
{
	public function addByLabel(name:String, label:String, ?frameRate:Float, ?looped:Bool):Void
	{
		var foundFrames:Array<Int> = [];
		var hasFoundLabel:Bool = false;
		var mainTimeline = _animate.library.timeline;

		for (layer in mainTimeline.layers)
		{
			for (frame in layer.frames)
			{
				if (frame.name == label)
				{
					hasFoundLabel = true;

					for (i in 0...frame.duration)
						foundFrames.push(frame.index + i);
				}
			}

			if (hasFoundLabel)
				break;
		}

		if (foundFrames.length <= 0)
		{
			FlxG.log.warn('No frames found with label "$label".');
			return;
		}

		frameRate ??= getDefaultFramerate();

		var anim = new FlxAnimateAnimation(this, name, foundFrames, frameRate, looped);
		anim.timeline = mainTimeline;
		_animations.set(name, anim);
	}

	public function addByTimeline(name:String, timeline:Timeline, ?frameRate:Float, ?looped:Bool):Void
	{
		addByTimelineIndices(name, timeline, [for (i in 0...timeline.frameCount) i], frameRate, looped);
	}

	public function addByTimelineIndices(name:String, timeline:Timeline, indices:Array<Int>, ?frameRate:Float, ?looped:Bool):Void
	{
		frameRate ??= getDefaultFramerate();
		var anim = new FlxAnimateAnimation(this, name, indices, frameRate, looped);
		anim.timeline = timeline;
		_animations.set(name, anim);
	}

	public function addBySymbol(name:String, symbolName:String, ?frameRate:Float, ?looped:Bool):Void
	{
		var symbol = _animate.library.getSymbol(symbolName);
		if (symbol == null)
			return;

		frameRate ??= getDefaultFramerate();

		var anim = new FlxAnimateAnimation(this, name, [for (i in 0...symbol.timeline.frameCount) i], frameRate, looped);
		anim.timeline = symbol.timeline;
		_animations.set(name, anim);
	}

	public function addBySymbolIndices(name:String, symbolName:String, indices:Array<Int>, ?frameRate:Float, ?looped:Bool):Void
	{
		var symbol = _animate.library.getSymbol(symbolName);
		if (symbol == null)
			return;

		frameRate ??= getDefaultFramerate();

		var anim = new FlxAnimateAnimation(this, name, indices, frameRate, looped);
		anim.timeline = symbol.timeline;
		_animations.set(name, anim);
	}

	override function set_frameIndex(frame:Int):Int
	{
		if (!isAnimate)
			return super.set_frameIndex(frame);

		if (numFrames > 0)
		{
			frame = frame % numFrames;
			_animate.timeline = cast(curAnim, FlxAnimateAnimation).timeline;
			_animate.timeline.currentFrame = frame;
			_animate.timeline.signalFrameChange(frame);
			frameIndex = frame;
			fireCallback();
		}

		return frameIndex;
	}

	var _animate(get, never):FlxAnimate;

	inline function get__animate():FlxAnimate
		return cast _sprite;

	var isAnimate(get, never):Bool;

	inline function get_isAnimate()
		return _animate.isAnimate;

	public inline function getDefaultFramerate():Float
		return _animate.library.frameRate;
}

class FlxAnimateAnimation extends FlxAnimation
{
	public var timeline:Timeline;

	override function getCurrentFrameDuration():Float
	{
		return frameDuration;
	}

	override function destroy()
	{
		super.destroy();
		timeline = null;
	}
}
