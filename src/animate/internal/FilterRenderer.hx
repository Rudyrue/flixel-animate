package animate.internal;

#if !flash
import animate.internal.elements.*;
import animate.internal.filters.MaskShader;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxPool;
import openfl.display.BitmapData;
import openfl.display.Graphics;
import openfl.display.OpenGLRenderer;
import openfl.display.Shader;
import openfl.display._internal.Context3DGraphics;
import openfl.filters.BitmapFilter;
import openfl.filters.BlurFilter;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;

@:access(flixel.FlxCamera)
@:access(flixel.graphics.frames.FlxFrame)
@:access(openfl.display.OpenGLRenderer)
@:access(openfl.display.Stage)
@:access(openfl.display3D.Context3D)
@:access(openfl.geom.Rectangle)
@:access(openfl.geom.Point)
@:access(openfl.display.internal.DrawCommandBuffer)
@:access(openfl.display.Graphics)
@:access(openfl.geom.ColorTransform)
@:access(openfl.display.BitmapData)
@:access(openfl.filters.BitmapFilter)
@:access(lime.graphics.Image)
@:access(openfl.display3D.textures.TextureBase)
class FilterRenderer
{
	public static function maskFrame(frame:Frame, currentFrame:Int, layer:Layer):Null<AtlasInstance>
	{
		var masker = layer.parentLayer;
		if (masker == null)
			return null;

		var maskerFrame = masker.getFrameAtIndex(currentFrame);
		if (maskerFrame == null)
			return null;

		var maskerBounds:Rectangle;
		var maskedBounds:Rectangle;

		var masker = renderToBitmap((cam, mat) ->
		{
			maskerFrame.draw(cam, currentFrame, null, mat, null, null, true, null);
			cam.render();
			maskerBounds = cam.canvas.getBounds(null);
		});

		var masked = renderToBitmap((cam, mat) ->
		{
			frame.draw(cam, currentFrame, null, mat, null, null, true, null);
			cam.render();
			maskedBounds = cam.canvas.getBounds(null);
		});

		var intersectX = Math.max(maskerBounds.x, maskedBounds.x);
		var intersectY = Math.max(maskerBounds.y, maskedBounds.y);
		var intersectWidth = Math.min(maskerBounds.right, maskedBounds.right) - intersectX;
		var intersectHeight = Math.min(maskerBounds.bottom, maskedBounds.bottom) - intersectY;

		var rect = Rectangle.__pool.get();
		var point = Point.__pool.get();

		rect.setTo(intersectX - maskedBounds.x, intersectY - maskedBounds.y, intersectWidth, intersectHeight);
		point.setTo(0, 0);

		// make masked bitmap
		var bitmap = new BitmapData(Math.ceil(maskerBounds.width), Math.ceil(maskerBounds.height), true, 0);
		bitmap.copyPixels(masked, rect, point, null, null, true);

		// copy masker channel
		rect.setTo(intersectX - maskerBounds.x, intersectY - maskerBounds.y, intersectWidth, intersectHeight);

		var frame = FlxGraphic.fromBitmapData(bitmap).imageFrame.frame;
		MaskShader.maskAlpha(bitmap, masker, rect);

		Rectangle.__pool.release(rect);
		Point.__pool.release(point);

		var element = new AtlasInstance();
		element.frame = frame;
		element.matrix = new FlxMatrix(1, 0, 0, 1, intersectX, intersectY);

		FlxDestroyUtil.dispose(masker);
		FlxDestroyUtil.dispose(masked);

		return element;
	}

	public static function renderGfx(gfx:Graphics):Null<BitmapData>
	{
		if (gfx.__bounds == null)
			return null;

		var cacheRTT = renderer.__context3D.__state.renderToTexture;
		var cacheRTTDepthStencil = renderer.__context3D.__state.renderToTextureDepthStencil;
		var cacheRTTAntiAlias = renderer.__context3D.__state.renderToTextureAntiAlias;
		var cacheRTTSurfaceSelector = renderer.__context3D.__state.renderToTextureSurfaceSelector;

		var bounds = gfx.__owner.getBounds(null);
		var bmp = new BitmapData(Math.ceil(bounds.width), Math.ceil(bounds.height), true, 0);

		renderer.__worldTransform.translate(-bounds.x, -bounds.y);

		var context = renderer.__context3D;

		renderer.__setRenderTarget(bmp);
		context.setRenderToTexture(bmp.getTexture(context));

		Context3DGraphics.render(gfx, renderer);

		renderer.__worldTransform.identity();

		var gl = renderer.__gl;
		var renderBuffer = bmp.getTexture(context);

		@:privateAccess
		gl.readPixels(0, 0, Math.round(bmp.width), Math.round(bmp.height), renderBuffer.__format, gl.UNSIGNED_BYTE, bmp.image.data);

		if (cacheRTT != null)
		{
			renderer.__context3D.setRenderToTexture(cacheRTT, cacheRTTDepthStencil, cacheRTTAntiAlias, cacheRTTSurfaceSelector);
		}
		else
		{
			renderer.__context3D.setRenderToBackBuffer();
		}

		return bmp;
	}

	static function renderToBitmap(draw:(FlxCamera, FlxMatrix) -> Void):BitmapData
	{
		AtlasInstance.__skipIsOnScreen = true;

		var cam = CamPool.get();
		var gfx = cam.canvas.graphics;
		draw(cam, new FlxMatrix());

		var bitmap:BitmapData = renderGfx(gfx);

		cam.clearDrawStack();
		gfx.clear();
		cam.put();

		AtlasInstance.__skipIsOnScreen = false;

		return bitmap;
	}

	public static function bakeFilters(symbol:SymbolInstance, filters:Array<BitmapFilter>, scale:FlxPoint):AtlasInstance
	{
		var bitmap:BitmapData;
		var bounds:Rectangle;
		var filteredBounds:Rectangle;

		bitmap = renderToBitmap((cam, mat) ->
		{
			mat.setTo(1 / scale.x, 0, 0, 1 / scale.y, 0, 0);
			symbol.draw(cam, 0, null, mat, null, null, true, null);
			cam.render();

			bounds = cam.canvas.getBounds(null);
			var gfx = cam.canvas.graphics;

			if (filters != null && filters.length > 0)
				@:privateAccess
			{
				var inflate = Rectangle.__pool.get();
				for (filter in filters)
				{
					if (filter == null)
						continue;

					if (filter is BlurFilter)
					{
						var blur:BlurFilter = cast filter;
						blur.blurX /= scale.x;
						blur.blurY /= scale.y;
					}

					inflate.__expand(-filter.__leftExtension,
						-filter.__topExtension, filter.__leftExtension
						+ filter.__rightExtension,
						filter.__topExtension
						+ filter.__bottomExtension);
				}

				var boundsX = bounds.x + inflate.x - scale.x;
				var boundsY = bounds.y + inflate.y - scale.y;

				gfx.__inflateBounds(boundsX, boundsY);
				gfx.__bounds.width += inflate.width;
				gfx.__bounds.height += inflate.height;

				Rectangle.__pool.release(inflate);
			}

			filteredBounds = cam.canvas.getBounds(null);
		});

		var frame = FlxGraphic.fromBitmapData(bitmap).imageFrame.frame;
		filterFrame(frame, filters);

		var mat = new FlxMatrix();
		mat.translate(filteredBounds.x, filteredBounds.y);
		mat.scale(scale.x, scale.y);
		mat.concat(symbol.matrix.clone().invert());

		var element = new AtlasInstance();
		element.frame = frame;
		element.matrix = mat;
		scale.put();

		return element;
	}

	public static function filterFrame(frame:FlxFrame, ?filters:Array<BitmapFilter>):Void
	{
		if (filters == null || filters.length <= 0)
			return;

		var f = frame.frame;
		var filterFrame = new FlxFrame(FlxGraphic.fromRectangle(Math.ceil(f.width), Math.ceil(f.height), 0, true));

		var _filterBmp1:BitmapData = new BitmapData(filterFrame.parent.width, filterFrame.parent.height, 0);
		var _filterBmp2:BitmapData = null;

		var needsPreserveObject:Bool = false;
		for (filter in filters)
		{
			if (filter != null && filter.__preserveObject)
				needsPreserveObject = true;
		}

		if (needsPreserveObject)
			_filterBmp2 = new BitmapData(_filterBmp1.width, _filterBmp1.height, true, 0);
		filterFrame.parent.bitmap = __applyFilter(filterFrame.parent.bitmap, _filterBmp1, _filterBmp2, frame.parent.bitmap, filters);

		filterFrame.frame = FlxRect.get(0, 0, filterFrame.parent.bitmap.width, filterFrame.parent.bitmap.height);
		filterFrame.copyTo(frame);
	}

	static function __applyFilter(target:BitmapData, target1:BitmapData, ?target2:BitmapData, bmp:BitmapData, filters:Array<BitmapFilter>, ?point:Point)
	{
		if (filters == null || filters.length == 0)
			return bmp;

		renderer.__setBlendMode(NORMAL);
		renderer.__worldAlpha = 1;

		if (renderer.__worldTransform == null)
		{
			renderer.__worldTransform = new Matrix();
			renderer.__worldColorTransform = new ColorTransform();
		}

		renderer.__worldTransform.identity();
		renderer.__worldColorTransform.__identity();

		var bitmap:BitmapData = target;
		var bitmap2:BitmapData = target1;
		var bitmap3:BitmapData = target2;

		renderer.__setRenderTarget(bitmap);

		var rect = Rectangle.__pool.get();
		rect.setTo(0, 0, bitmap.width, bitmap.height);

		bmp.__renderTransform.identity();
		if (point != null)
			bmp.__renderTransform.translate(point.x, point.y);

		var bestResolution = renderer.__context3D.__backBufferWantsBestResolution;
		renderer.__context3D.__backBufferWantsBestResolution = false;
		renderer.__scissorRect(rect);
		renderer.__renderFilterPass(bmp, renderer.__defaultDisplayShader, true);
		renderer.__scissorRect();

		Rectangle.__pool.release(rect);

		renderer.__context3D.__backBufferWantsBestResolution = bestResolution;

		var shader, cacheBitmap = null;
		for (filter in filters)
		{
			if (filter == null)
				continue;

			if (filter.__preserveObject)
			{
				renderer.__setRenderTarget(bitmap3);
				renderer.__renderFilterPass(bitmap, renderer.__defaultDisplayShader, filter.__smooth);
			}

			for (i in 0...filter.__numShaderPasses)
			{
				shader = filter.__initShader(renderer, i, (filter.__preserveObject) ? bitmap3 : null);
				renderer.__setBlendMode(filter.__shaderBlendMode);
				renderer.__setRenderTarget(bitmap2);
				renderer.__renderFilterPass(bitmap, shader, filter.__smooth);

				cacheBitmap = bitmap;
				bitmap = bitmap2;
				bitmap2 = cacheBitmap;
			}
			filter.__renderDirty = false;
		}

		var gl = renderer.__gl;
		var renderBuffer = bitmap.getTexture(renderer.__context3D);

		@:privateAccess
		gl.readPixels(0, 0, bitmap.width, bitmap.height, renderBuffer.__format, gl.UNSIGNED_BYTE, bitmap.image.data);
		bitmap.image.version = 0;
		bitmap.__textureVersion = -1;

		if (target1 != bitmap)
			FlxDestroyUtil.dispose(target1);

		FlxDestroyUtil.dispose(target2);

		return bitmap;
	}

	public static function renderWithShader(target:BitmapData, bitmap:BitmapData, shader:Shader):Void @:privateAccess
	{
		var renderer = FilterRenderer.renderer;
		renderer.__setRenderTarget(target);

		target.__renderTransform.identity();
		renderer.__renderFilterPass(bitmap, shader, true);

		var gl = renderer.__gl;
		var renderBuffer = target.getTexture(renderer.__context3D);

		gl.readPixels(0, 0, target.width, target.height, renderBuffer.__format, gl.UNSIGNED_BYTE, target.image.data);
		target.image.version = 0;
		target.__textureVersion = -1;
	}

	static var renderer(get, null):OpenGLRenderer;

	static function get_renderer()
		return (renderer != null) ? renderer : (renderer = __createRenderer());

	static function __createRenderer():OpenGLRenderer
	{
		var renderer = new OpenGLRenderer(FlxG.game.stage.context3D);
		renderer.__worldTransform = new Matrix();
		renderer.__worldColorTransform = new ColorTransform();
		return renderer;
	}
}

class CamPool extends FlxCamera implements IFlxPooled
{
	public static final pool:FlxPool<CamPool> = new FlxPool(PoolFactory.fromFunction(() -> new CamPool()));

	public static function get()
	{
		return pool.get();
	}

	public function put()
	{
		pool.putUnsafe(this);
	}

	override function destroy() {}
}
#end
