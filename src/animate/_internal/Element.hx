package animate._internal;

import animate.FlxAnimateJson;
import animate._internal.filters.*;
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

typedef Element = AnimateElement<Dynamic>;

class AnimateElement<T> implements IFlxDestroyable
{
	var _mat:FlxMatrix;

	public var matrix:FlxMatrix;
	public var visible:Bool;
	public var isSymbolInstance:Bool;

	public function new(data:T, parent:FlxAnimateFrames, ?frame:Frame)
	{
		_mat = new FlxMatrix();
		visible = true;
	}

	public function destroy()
	{
		_mat = null;
		matrix = null;
	}

	public function draw(camera:FlxCamera, index:Int, tlFrame:Frame, parentMatrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?antialiasing:Bool,
		?shader:FlxShader):Void {}

	public inline function toSymbolInstance():SymbolInstance
		return cast this;

	public inline function toAtlasInstance():AtlasInstance
		return cast this;

	public inline function toButtonInstance():ButtonInstance
		return cast this;

	public function getBounds(?rect:FlxRect, ?matrix:FlxMatrix):FlxRect
	{
		return rect ?? FlxRect.get();
	}
}

class SymbolInstance extends AnimateElement<SymbolInstanceJson>
{
	var libraryItem:SymbolItem;

	var blend:BlendMode;
	var firstFrame:Int;
	var loopType:String;
	var isMovieClip:Bool;

	var transform:ColorTransform;
	var _transform:ColorTransform;

	override function destroy()
	{
		super.destroy();
		libraryItem = null;
		transform = null;
		_transform = null;

		if (bakedElement != null)
		{
			bakedElement.frame.destroy();
			bakedElement = FlxDestroyUtil.destroy(bakedElement);
		}
	}

	public function new(data:SymbolInstanceJson, parent:FlxAnimateFrames, ?frame:Frame)
	{
		super(data, parent);

		isSymbolInstance = true;
		libraryItem = parent.getSymbol(data.SN);
		this.matrix = data.MX.toMatrix();
		this.loopType = data.LP;
		this.isMovieClip = data.ST == "MC" || data.ST == "movieclip";

		var color = data.C;
		if (color != null)
		{
			transform = new ColorTransform();
			_transform = new ColorTransform();
			switch (color.M)
			{
				case "AD" | "Advanced":
					transform.setMultipliers(color.RM, color.GM, color.BM, color.AM);
					transform.setOffsets(color.RO, color.GO, color.BO, color.AO);
				case "CA" | "Alpha":
					transform.alphaMultiplier = color.AM;
				case "CBRT" | "Brightness":
					var brt = color.BRT * 255;
					transform.setOffsets(brt, brt, brt, 0);
				case "T" | "Tint":
					var m = color.TM;
					var c = FlxColor.fromString(color.TC);
					var mult = 1 - m;
					transform.setMultipliers(mult, mult, mult, 1);
					transform.setOffsets(c.red * m, c.green * m, c.blue * m, 0);
			}
		}

		if (isMovieClip)
		{
			this.blend = #if flash Blend.resolveBlend(data.B); #else data.B; #end

			#if !flash
			this.filters = data.F;

			// Set filters dirty
			if (this.filters != null && this.filters.length > 0)
				_dirty = true;

			// Set whole frame for blending
			// if (this.blend != null && !Blend.isGpuSupported(this.blend))
			//	frame._dirty = true;
			#end
		}
		else
		{
			this.firstFrame = data.FF;
		}

		if (libraryItem == null)
			visible = false;
	}

	var bakedElement:AtlasInstance = null;

	var filters:Array<FilterJson> = null;
	var _dirty:Bool = false;

	function bakeFilters(?filters:Array<FilterJson>):Void
	{
		#if !flash
		if (!isMovieClip || filters == null || filters.length <= 0)
			return;

		var bitmapFilters:Array<BitmapFilter> = [];
		var scale = FlxPoint.get(1, 1);

		for (filter in filters)
		{
			var bmFilter:BitmapFilter = null;
			switch (filter.N)
			{
				case "blurFilter" | "BLF":
					var quality:Int = filter.Q;
					var blurX:Float = filter.BLX * 0.75;
					var blurY:Float = filter.BLY * 0.75;

					bmFilter = new BlurFilter(blurX, blurY, quality);
					scale.x *= Math.max((blurX / 16) * (quality * 1.75), 1);
					scale.y *= Math.max((blurY / 16) * (quality * 1.75), 1);

				case "adjustColorFilter" | "ACF":
					var colorFilter = new AdjustColorFilter();
					colorFilter.set(filter.BRT, filter.H, filter.CT, filter.SAT);
					bmFilter = colorFilter.filter;

				default: // TODO: add missing filters
			}

			if (bmFilter != null)
				bitmapFilters.push(bmFilter);
		}

		bakedElement = FilterRenderer.bakeFilters(this, bitmapFilters, scale);
		libraryItem = null;
		#end
	}

	override function draw(camera:FlxCamera, index:Int, tlFrame:Frame, parentMatrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode,
			?antialiasing:Bool, ?shader:FlxShader):Void
	{
		if (_dirty)
		{
			_dirty = false;
			bakeFilters(this.filters);
		}

		_mat.copyFrom(matrix);
		_mat.concat(parentMatrix);

		// Is colored
		if (this.transform != null)
		{
			var t = this.transform;
			_transform.setMultipliers(t.redMultiplier, t.greenMultiplier, t.blueMultiplier, t.alphaMultiplier);
			_transform.setOffsets(t.redOffset, t.greenOffset, t.blueOffset, t.alphaOffset);

			if (transform != null)
				_transform.concat(transform);

			transform = _transform;

			if (transform.alphaMultiplier <= 0)
				return;
		}

		final blend:Null<BlendMode> = this.blend ?? blend;

		if (isMovieClip && bakedElement != null && bakedElement.visible)
		{
			bakedElement.draw(camera, 0, null, _mat, transform, blend, antialiasing, shader);
			return;
		}

		libraryItem.timeline.currentFrame = getFrameIndex(index, tlFrame);
		libraryItem.timeline.draw(camera, _mat, transform, blend, antialiasing, shader);
	}

	function getFrameIndex(index:Int, frame:Frame):Int
	{
		if (isMovieClip)
			return 0;

		var frameIndex = firstFrame + (index - frame.index);
		var frameCount = libraryItem.timeline.frameCount;

		switch (loopType)
		{
			case "LP" | "loop":
				frameIndex = FlxMath.wrap(frameIndex, 0, frameCount - 1);
			case "PO" | "playonce":
				frameIndex = Std.int(Math.min(frameIndex, frameCount - 1));
			case "SF" | "singleframe":
				frameIndex = firstFrame;
		}

		return frameIndex;
	}

	final tmpMatrix:FlxMatrix = new FlxMatrix();

	override function getBounds(?rect:FlxRect, ?matrix:FlxMatrix):FlxRect
	{
		var targetMatrix:FlxMatrix;
		if (matrix != null)
		{
			tmpMatrix.copyFrom(this.matrix);
			tmpMatrix.concat(matrix);
			targetMatrix = tmpMatrix;
		}
		else
			targetMatrix = this.matrix;

		if (bakedElement != null)
			return bakedElement.getBounds(rect, targetMatrix);

		return libraryItem.timeline.getBounds(libraryItem.timeline.currentFrame, null, rect, targetMatrix);
	}

	public function toString():String
	{
		return '{name: ${libraryItem.name}, matrix: $matrix}';
	}
}

@:access(openfl.geom.Point)
@:access(openfl.geom.Matrix)
@:access(flixel.graphics.frames.FlxFrame)
class AtlasInstance extends AnimateElement<AtlasInstanceJson>
{
	public var frame:FlxFrame;

	public function new(?data:AtlasInstanceJson, ?parent:FlxAnimateFrames, ?frame:Frame)
	{
		super(data, parent);
		isSymbolInstance = false;
		if (data != null)
		{
			this.frame = parent.getByName(data.N);
			this.matrix = data.MX.toMatrix();

			#if flash // FlxFrame.paint doesnt work for rotated frames lol
			var bitmap = this.frame.checkInputBitmap(null, null, this.frame.angle);
			var mat = this.frame.fillBlitMatrix(FlxFrame._matrix);
			bitmap.draw(this.frame.parent.bitmap, mat, null, null, this.frame.getDrawFrameRect(mat, FlxFrame._rect));
			this.frame = FlxGraphic.fromBitmapData(bitmap).imageFrame.frame;
			#end
		}
	}

	public function replaceFrame(frame:FlxFrame, adjustScale:Bool = true):Void
	{
		var copyFrame = frame.copyTo();

		// Scale adjustment
		if (adjustScale)
		{
			var lastFrame = this.frame;
			copyFrame.tileMatrix[0] = lastFrame.frame.width / frame.frame.width;
			copyFrame.tileMatrix[3] = lastFrame.frame.height / frame.frame.height;
		}

		this.frame = copyFrame;
	}

	override function destroy():Void
	{
		super.destroy();
		frame = null;
	}

	override function draw(camera:FlxCamera, index:Int, tlFrame:Frame, parentMatrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode,
			?antialiasing:Bool, ?shader:FlxShader):Void
	{
		if (frame == null) // should add a warn here
			return;

		frame.prepareMatrix(_mat);
		_mat.concat(matrix);
		_mat.concat(parentMatrix);

		if (!isOnScreen(camera, _mat))
			return;

		#if flash
		drawPixelsFlash(camera, _mat, transform, blend, antialiasing);
		#else
		camera.drawPixels(frame, null, _mat, transform, blend, antialiasing, shader);
		#end

		#if FLX_DEBUG
		if (FlxG.debugger.drawDebug)
			drawBoundingBox(camera, _bounds);
		#end
	}

	#if flash
	@:access(flixel.FlxCamera)
	function drawPixelsFlash(cam:FlxCamera, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?antialiasing:Bool):Void
	{
		var smooth:Bool = (cam.antialiasing || antialiasing);
		cam._helperMatrix.copyFrom(matrix);

		if (cam._useBlitMatrix)
		{
			cam._helperMatrix.concat(cam._blitMatrix);
			cam.buffer.draw(frame.parent.bitmap, cam._helperMatrix, transform, blend, null, smooth);
		}
		else
		{
			cam._helperMatrix.translate(-cam.viewMarginLeft, -cam.viewMarginTop);
			cam.buffer.draw(frame.parent.bitmap, cam._helperMatrix, transform, blend, null, smooth);
		}
	}
	#end

	static var p1 = FlxPoint.get();
	static var p2 = FlxPoint.get();
	static var p3 = FlxPoint.get();
	static var p4 = FlxPoint.get();

	var _bounds:FlxRect = FlxRect.get();

	@:allow(animate._internal.FilterRenderer)
	private static var __skipIsOnScreen:Bool = false;

	public function isOnScreen(camera:FlxCamera, matrix:FlxMatrix):Bool
	{
		if (__skipIsOnScreen)
			return true;

		var bounds = _bounds.set(0, 0, frame.frame.width, frame.frame.height);
		Timeline.applyMatrixToRect(bounds, matrix);

		return camera.containsRect(bounds);
	}

	override function getBounds(?rect:FlxRect, ?matrix:FlxMatrix):FlxRect
	{
		var rect = super.getBounds(rect);
		rect.set(0, 0, frame.frame.width, frame.frame.height);

		Timeline.applyMatrixToRect(rect, frame.prepareMatrix(_mat));
		Timeline.applyMatrixToRect(rect, this.matrix);
		if (matrix != null)
			Timeline.applyMatrixToRect(rect, matrix);

		return rect;
	}

	#if FLX_DEBUG
	public static function drawBoundingBox(camera:FlxCamera, rect:FlxRect, ?color:FlxColor = FlxColor.BLUE):Void
	{
		var gfx = camera.debugLayer.graphics;
		gfx.lineStyle(1, color, 0.75);
		gfx.drawRect(rect.x + 0.5, rect.y + 0.5, rect.width - 1.0, rect.height - 1.0);
	}
	#end

	public function toString():String
	{
		return '{frame: ${frame.name}, matrix: $matrix}';
	}
}

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
