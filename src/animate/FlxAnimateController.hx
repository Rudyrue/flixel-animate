package animate;

import animate.internal.*;
import flixel.FlxG;
import flixel.animation.FlxAnimation;
import flixel.animation.FlxAnimationController;

class FlxAnimateController extends FlxAnimationController
{
	public function addByFrameLabel(name:String, label:String, ?frameRate:Float, ?looped:Bool):Void
	{
		if (!isAnimate)
		{
			FlxG.log.warn('Sprite is not loaded with a texture atlas.');
			return;
		}

		var foundFrames = findFrameLabelIndices(label);

		if (foundFrames.length <= 0)
		{
			FlxG.log.warn('No frames found with label "$label".');
			return;
		}

		frameRate ??= getDefaultFramerate();

		var anim = new FlxAnimateAnimation(this, name, foundFrames, frameRate, looped);
		anim.timeline = _animate.library.timeline;
		_animations.set(name, anim);
	}

	public function addByFrameLabelIndices(name:String, label:String, indices:Array<Int>, ?frameRate:Float, ?looped:Bool)
	{
		if (!isAnimate)
		{
			FlxG.log.warn('Sprite is not loaded with a texture atlas.');
			return;
		}

		var foundFrames:Array<Int> = findFrameLabelIndices(label);
		var useableFrames:Array<Int> = [];

		for (index in indices)
		{
			var frameIndex:Null<Int> = foundFrames[index];
			if (frameIndex != null)
				useableFrames.push(frameIndex);
		}

		if (useableFrames.length <= 0)
		{
			FlxG.log.warn('No frames useable with label "$label" and indices $indices.');
			return;
		}

		frameRate ??= getDefaultFramerate();

		var anim = new FlxAnimateAnimation(this, name, useableFrames, frameRate, looped);
		anim.timeline = _animate.library.timeline;
		_animations.set(name, anim);
	}

	public function addByTimeline(name:String, timeline:Timeline, ?frameRate:Float, ?looped:Bool):Void
	{
		if (!isAnimate)
		{
			FlxG.log.warn('Sprite is not loaded with a texture atlas.');
			return;
		}

		addByTimelineIndices(name, timeline, [for (i in 0...timeline.frameCount) i], frameRate, looped);
	}

	public function addByTimelineIndices(name:String, timeline:Timeline, indices:Array<Int>, ?frameRate:Float, ?looped:Bool):Void
	{
		if (!isAnimate)
		{
			FlxG.log.warn('Sprite is not loaded with a texture atlas.');
			return;
		}

		frameRate ??= getDefaultFramerate();
		var anim = new FlxAnimateAnimation(this, name, indices, frameRate, looped);
		anim.timeline = timeline;
		_animations.set(name, anim);
	}

	public function addBySymbol(name:String, symbolName:String, ?frameRate:Float, ?looped:Bool):Void
	{
		if (!isAnimate)
		{
			FlxG.log.warn('Sprite is not loaded with a texture atlas.');
			return;
		}

		var symbol = _animate.library.getSymbol(symbolName);
		if (symbol == null)
		{
			FlxG.log.warn('Symbol not found with name "$symbolName"');
			return;
		}

		frameRate ??= getDefaultFramerate();

		var anim = new FlxAnimateAnimation(this, name, [for (i in 0...symbol.timeline.frameCount) i], frameRate, looped);
		anim.timeline = symbol.timeline;
		_animations.set(name, anim);
	}

	public function addBySymbolIndices(name:String, symbolName:String, indices:Array<Int>, ?frameRate:Float, ?looped:Bool):Void
	{
		if (!isAnimate)
		{
			FlxG.log.warn('Sprite is not loaded with a texture atlas.');
			return;
		}

		var symbol = _animate.library.getSymbol(symbolName);
		if (symbol == null)
		{
			FlxG.log.warn('Symbol not found with name "$symbolName"');
			return;
		}

		frameRate ??= getDefaultFramerate();

		var anim = new FlxAnimateAnimation(this, name, indices, frameRate, looped);
		anim.timeline = symbol.timeline;
		_animations.set(name, anim);
	}

	public function findFrameLabelIndices(label:String):Array<Int>
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

		return foundFrames;
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
