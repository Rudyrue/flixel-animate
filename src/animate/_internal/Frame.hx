package animate._internal;

import animate.FlxAnimateJson.FrameJson;
import animate._internal.Element;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.math.FlxMatrix;
import flixel.sound.FlxSound;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxDestroyUtil;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;

@:nullSafety(Strict)
class Frame implements IFlxDestroyable
{
	public var layer:Null<Layer>;
	public var elements:Array<Element>;
	public var index:Int;
	public var duration:Int;
	public var name:String;

	public function new(?layer:Layer)
	{
		this.elements = [];
		this.name = "";
		this.layer = layer;
		this.duration = 0;
		this.index = 0;
	}

	public var sound:Null<FlxSound>;

	@:allow(animate._internal.Layer)
	function __loadJson(frame:FrameJson, parent:FlxAnimateFrames):Void
	{
		this.index = frame.I;
		this.duration = frame.DU;
		this.name = frame.N ?? "";
		for (element in frame.E)
		{
			var si = element.SI;
			this.elements.push((si != null) ? new SymbolInstance(element.SI, parent) : new AtlasInstance(element.ASI, parent));
		}

		if (frame.SND != null)
		{
			sound = FlxG.sound.load(parent.path + '/LIBRARY/' + frame.SND.N);
		}
	}

	public function destroy():Void
	{
		elements = FlxDestroyUtil.destroyArray(elements);
		sound = FlxDestroyUtil.destroy(sound);
		layer = null;
	}

	@:allow(animate._internal.Layer)
	var _dirty:Bool = false;
	var bakedElement:Null<AtlasInstance> = null;

	function bakeFrame(currentFrame:Int, layer:Layer):Void
	{
		#if !flash
		if (layer.parentLayer == null)
			return;

		bakedElement = FilterRenderer.maskFrame(this, currentFrame, layer);

		if (bakedElement != null && (bakedElement.frame.frame.width <= 1 || bakedElement.frame.frame.height <= 1))
			bakedElement.visible = false;
		#end
	}

	public function forEachElement(callback:Element->Void):Void
	{
		for (element in elements)
			callback(element);
	}

	public function draw(camera:FlxCamera, currentFrame:Int, layer:Layer, parentMatrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode,
			?antialiasing:Bool, ?shader:FlxShader):Void
	{
		if (_dirty)
		{
			_dirty = false;
			bakeFrame(currentFrame, layer);
		}

		if (bakedElement != null)
		{
			if (bakedElement.visible)
				bakedElement.draw(camera, currentFrame, this, parentMatrix, transform, blend, antialiasing, shader);
			return;
		}

		for (element in elements)
		{
			if (element.visible)
				element.draw(camera, currentFrame, this, parentMatrix, transform, blend, antialiasing, shader);
		}
	}

	public function toString():String
	{
		return '{name: "$name", index: $index, duration: $duration}';
	}
}
