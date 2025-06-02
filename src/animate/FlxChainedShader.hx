package animate;

import flixel.system.FlxAssets.FlxShader;

using StringTools;

/**
 * FlxShader for combining multiple shaders into one.
 * Similar to a multi-pass shader.
 * Though what it does is combine the code of all the shaders into one.
 * @author MaybeMaru
 */
class FlxChainedShader extends #if !flash flixel.addons.display.FlxRuntimeShader #else FlxShader #end
{
	// TODO: add a "setShaders" function
	// TODO: vertex source combiner
	public function new(?shaders:Array<FlxShader>)
	{
		this.__shaders = shaders;
		__shaderValues.resize(0);
		__pushedVariables.resize(0);

		var fragments:Array<String> = [];

		for (i => shader in shaders)
		{
			var logic = extractShaderLogic(shader.glFragmentSource, i);
			__shaderValues.push(logic.updateVars);

			fragments.push('

			${logic.other.join('\n')}

			vec4 $APPLY_SHADER_ID$i(sampler2D bitmap, vec2 openfl_TextureCoordv)
			{
				${logic.main}
				return finalColor;
			}
			');
		}

		var fragBuf:StringBuf = new StringBuf();

		fragBuf.add('#pragma header');
		fragBuf.add("\n");

		for (frag in fragments)
		{
			fragBuf.add(frag);
			fragBuf.add("\n");
		}

		fragBuf.add('
			void main()
			{
				gl_FragColor = $APPLY_SHADER_ID${shaders.length - 1}(bitmap, openfl_TextureCoordv);
			}
		');

		super(#if !flash fragBuf.toString() #end);
	}

	var __shaders:Array<FlxShader> = [];
	var __shaderValues:Array<Array<Array<String>>> = [];
	var __pushedVariables:Array<String> = [];

	static inline var APPLY_SHADER_ID:String = "__applyShader";

	private function __prepareValues():Void
	{
		for (i => shader in __shaders)
		{
			var values = __shaderValues[i];
			for (value in values)
			{
				var param = Reflect.field(data, value[0]);
				var valueParam = Reflect.field(shader.data, value[1]);
				param.value = valueParam.value;
			}
		}
	}

	#if !flash
	override function __init()
	{
		__prepareValues();
		super.__init();
	}
	#end

	private function extractShaderLogic(source:String, index:Int):ShaderLogic
	{
		var mainBuf = new StringBuf();
		var other:Array<String> = [];
		var updateVars:Array<Array<String>> = [];
		var knownVars:Array<String> = [];

		var lines = source.split("\n");
		var end = __findHeaderEnd(lines, "vec4 flixel_texture2D");
		lines.splice(0, end + 1); // remove openfl header crap

		final sanitizeLine:String->String = (line:String) ->
		{
			// color value inheritance
			if (index > 0)
			{
				line = line.replace('flixel_texture2D', '$APPLY_SHADER_ID${index - 1}');
				line = line.replace('texture2D', '$APPLY_SHADER_ID${index - 1}');
			}

			// relace duplicate value names
			for (i => value in knownVars)
			{
				if (line.contains(value))
					line = line.replace(value, updateVars[i][0]);
			}

			return line;
		}

		for (l => line in lines)
		{
			line = line.trim();
			if (line.startsWith('//'))
				continue;

			if (line.contains('main'))
			{
				var openedCurls:Int = 0;

				var i = l + 1;
				while (!lines[i - 1].contains('{'))
					i++;

				while (true)
				{
					var line = lines[i++];

					if (line.contains('}'))
					{
						if (openedCurls > 0)
							openedCurls--;
						else
							break;
					}

					if (line.contains('{'))
						openedCurls++;

					line = line.replace('gl_FragColor = ', 'vec4 finalColor = ');
					line = sanitizeLine(line);

					mainBuf.add(line);
					mainBuf.add('\n');
				}
				break;
			}
			else
			{
				if (line.contains('uniform'))
				{
					var name = line.split(" ").pop().replace(";", "");
					var pushName = name;

					var id = 0;
					while (__pushedVariables.contains(pushName))
					{
						pushName = '$name$id';
						id++;
					}

					line = line.replace(name, pushName);
					updateVars.push([pushName, name]);
					knownVars.push(name);
					__pushedVariables.push(pushName);
				}
				else
				{
					line = sanitizeLine(line);
				}

				other.push(line);
			}
		}

		return {
			main: mainBuf.toString(),
			updateVars: updateVars,
			other: other
		}
	}

	function __findHeaderEnd(lines:Array<String>, id:String):Int
	{
		var startIndex = -1;
		for (i in 0...lines.length)
		{
			if (lines[i].contains(id))
			{
				startIndex = i;
				break;
			}
		}

		var depth = 0;
		for (i in startIndex...lines.length)
		{
			var line = lines[i];

			var hasOpen = line.contains("{");
			if (hasOpen)
				depth++;

			var hasEnd = line.contains("}");
			if (hasEnd)
				depth--;

			if (hasEnd && depth == 0)
				return i;
		}

		return -1;
	}
}

typedef ShaderLogic =
{
	main:String,
	updateVars:Array<Array<String>>,
	other:Array<String>
}
