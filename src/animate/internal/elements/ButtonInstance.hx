package animate.internal.elements;

import animate.FlxAnimateJson;
import animate.internal.filters.*;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSignal;
import openfl.display.BlendMode;
import openfl.display.Timeline;
import openfl.filters.BitmapFilter;
import openfl.filters.BlurFilter;
import openfl.geom.ColorTransform;

using flixel.util.FlxColorTransformUtil;

class ButtonInstance extends SymbolInstance
{
	public function new(data:SymbolInstanceJson, parent:FlxAnimateFrames)
	{
		super(data, parent);

		this.isMovieClip = false;
		this.curButtonState = ButtonState.UP;
		this.onClick = new FlxSignal();
		this._hitbox = FlxRect.get();
	}

	public var curButtonState(default, null):ButtonState;

	public var onClick:FlxSignal;

	override function getFrameIndex(index:Int, frame:Frame):Int
	{
		return curButtonState;
	}

	override function draw(camera:FlxCamera, index:Int, tlFrame:Frame, parentMatrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode,
			?antialiasing:Bool, ?shader:FlxShader)
	{
		updateButtonState(camera, parentMatrix);

		super.draw(camera, index, tlFrame, parentMatrix, transform, blend, antialiasing, shader);

		#if FLX_DEBUG
		if (FlxG.debugger.drawDebug)
			AtlasInstance.drawBoundingBox(camera, _hitbox, FlxColor.PURPLE);
		#end
	}

	var _hitbox:FlxRect;

	static var mousePos:FlxPoint = FlxPoint.get();

	function updateButtonState(camera:FlxCamera, drawMatrix:FlxMatrix)
	{
		_hitbox = getBounds(_hitbox, drawMatrix);

		var mousePos = FlxG.mouse.getViewPosition(camera, mousePos);
		var isOverlaped = _hitbox.containsXY(mousePos.x, mousePos.y);

		if (isOverlaped)
		{
			this.curButtonState = FlxG.mouse.pressed ? ButtonState.DOWN : ButtonState.OVER;
			if (FlxG.mouse.justPressed)
				onClick.dispatch();
		}
		else
		{
			this.curButtonState = ButtonState.UP;
		}
	}

	override function getBounds(?rect:FlxRect, ?matrix:FlxMatrix):FlxRect
	{
		var bounds = this.libraryItem.timeline.getBounds(ButtonState.HIT, false, rect, this.matrix);
		if (matrix != null)
			bounds = Timeline.applyMatrixToRect(bounds, matrix);
		return bounds;
	}

	override function destroy()
	{
		super.destroy();
		_hitbox = FlxDestroyUtil.put(_hitbox);
		onClick = null;
	}
}

enum abstract ButtonState(Int) to Int
{
	var UP = 0;
	var OVER = 1;
	var DOWN = 2;
	var HIT = 3;
}
