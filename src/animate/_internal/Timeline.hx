package animate._internal;

import animate.FlxAnimateJson.TimelineJson;
import flixel.FlxCamera;
import flixel.math.FlxMatrix;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxDestroyUtil;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;

class Timeline implements IFlxDestroyable
{
	public var libraryItem:SymbolItem;
	public var layers:Array<Layer>;
	public var name:String;
	public var currentFrame:Int;
	public var frameCount:Int;

	var __layerMap:Map<String, Layer>;
	var parent:FlxAnimateFrames;

	public function new(timeline:TimelineJson, parent:FlxAnimateFrames, ?name:String)
	{
		layers = [];
		currentFrame = 0;
		this.parent = parent;

		if (name != null)
			this.name = name;

		var layersJson = timeline.L;

		__layerMap = [];
		for (layerJson in layersJson)
		{
			var layer = new Layer(this);
			layer.name = layerJson.LN;
			layers.unshift(layer);
			__layerMap.set(layer.name, layer);
		}

		for (i => layerJson in layersJson)
		{
			var layer = layers[layers.length - i - 1];
			layer.__loadJson(layerJson, parent, __layerMap);

			if (layer.frameCount > frameCount)
				frameCount = layer.frameCount;
		}
	}

	public function destroy():Void
	{
		parent = null;
		libraryItem = null;
		layers = FlxDestroyUtil.destroyArray(layers);
	}

	public function signalFrameChange(frameIndex:Int)
	{
		for (layer in layers)
		{
			var frame = layer.getFrameAtIndex(frameIndex);
			if (frame != null)
			{
				if (frame.sound != null && frame.index == frameIndex)
				{
					frame.sound.play(true);
				}
			}
		}
	}

	public function getLayer(name:String):Null<Layer>
	{
		return __layerMap.get(name);
	}

	public function forEachLayer(callback:Layer->Void):Void
	{
		for (layer in layers)
			callback(layer);
	}

	public function getFramesAtIndex(index:Int):Array<Frame>
	{
		var frames:Array<Frame> = [];
		for (layer in layers)
		{
			var frame = layer.getFrameAtIndex(index);
			if (frame != null)
				frames.push(frame);
		}
		return frames;
	}

	public function getElementsAtIndex(index:Int):Array<Element>
	{
		var elements:Array<Element> = [];
		for (layer in layers)
		{
			var frame = layer.getFrameAtIndex(index);
			if (frame != null)
			{
				for (element in frame.elements)
					elements.push(element);
			}
		}
		return elements;
	}

	public function getCurrentElements():Array<Element>
	{
		return getElementsAtIndex(currentFrame);
	}

	public function draw(camera:FlxCamera, parentMatrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?antialiasing:Bool, ?shader:FlxShader)
	{
		for (layer in layers)
		{
			if (!layer.visible)
				continue;

			var frame = layer.getFrameAtIndex(currentFrame);
			if (frame == null)
				continue;

			frame.draw(camera, currentFrame, layer, parentMatrix, transform, blend, antialiasing, shader);
		}
	}

	public function toString():String
	{
		return '{name: $name, frameCount: $frameCount}';
	}
}
